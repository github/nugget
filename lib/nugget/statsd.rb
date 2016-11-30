module Nugget
  class NStatsd # NStatsd since Statsd collides

    def self.send_metrics(name, result, response)
      statsd = self.stats
      send_test_result(statsd, name, result, response)
      send_test_timings(statsd, name, result, response)
    end

    protected

    def self.stats
      @stats ||= Statsd.new(Nugget::Config.statsd_host, Nugget::Config.statsd_port, Nugget::Config.statsd_key).tap do |statsd|
        statsd.namespace =  Nugget::Config.statsd_namespace
      end
    end

    def self.gauge(statsd, name, stat, boolean)
      count = boolean ? 1 : 0
      metric = "#{name}.#{stat}.count"
      statsd.gauge(metric, count)
      Nugget::Log.debug("Sending the following to statsd: #{metric}: #{count}")
    end

    def self.timing(statsd, name, stat, value)
      key = "#{name}.#{stat}"
      statsd.timing(key, value)
      Nugget::Log.debug("Sending the following to statsd: #{key}: #{value}")
    end

    private

    def self.send_test_result(statsd, name, result, response)
      failure = (result == "FAIL")
      dns_failure = failure && response.is_a?(Hash) && response[:return_code] == :couldnt_resolve_host
      tcp_failure = failure && response.is_a?(Hash) && [:couldnt_connect, :operation_timedout].include?(response[:return_code])
      tls_failure = failure && response.is_a?(Hash) && [:ssl_connect_error, :ssl_cacert].include?(response[:return_code])

      # If we failed but for a non distinct protocol reason, and the response
      # includes the `response_code` key, it must be an http layer check which
      # failed
      http_failure = failure && response.is_a?(Hash) && response.key?(:response_code) && !(dns_failure || tcp_failure || tls_failure)

      gauge(statsd, name, "failures", failure)
      gauge(statsd, name, "failures.dns", dns_failure)
      gauge(statsd, name, "failures.tcp", tcp_failure)
      gauge(statsd, name, "failures.tls", tls_failure)
      gauge(statsd, name, "failures.http", http_failure)

      # A holistic timeout means we don't have accurate data around which
      # protocol layer failed.
      timeout = (response == "timeout")
      gauge(statsd, name, "failures.timeout", timeout)
    end


    def self.send_test_timings(statsd, name, result, response)
      if response
        if response == "timeout"
          timing(statsd, name, "timout", TIMEOUT)
        else
          response.each do |key, value|
            if key.to_s.include?("_time")
              timing(statsd, name, key, value)
            end
          end
        end
      end
    end

  end
end
