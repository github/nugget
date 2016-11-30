module Nugget
  class DataDog < NStatsd
    def self.prefix
      @prefix ||= Nugget::Config.datadog_prefix
    end

    def self.stats
      @stats ||= Datadog::Statsd.new(Nugget::Config.datadog_host, Nugget::Config.datadog_port)
    end

    def self.default_tags
      @default_tags ||= Nugget::Config.datadog_tags.split(',')
    end

    def self.gauge(client, name, stat, boolean)
      count = boolean ? 1 : 0
      metric = "#{prefix}.#{stat}.count"
      tags = datadog_tags(name)
      client.gauge(metric, count, :tags => tags)

      Nugget::Log.debug("Sending the following to DataDog: #{metric}: #{count} (#{tags})")
    end

    def self.timing(client, name, stat, value)
      key = "#{prefix}.#{stat}"
      tags = datadog_tags(name)
      client.timing(key, value, :tags => tags)
      Nugget::Log.debug("Sending the following to DataDog: #{key}: #{value} (#{tags})")
    end

    def self.datadog_tags(name)
      ["nugget_check:#{name}"] + default_tags
    end
  end
end
