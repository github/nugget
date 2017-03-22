require 'net/ssh'
require 'turd'

module Turd
  class SSH
    def self.request(request_definition)
      options = request_definition.fetch(:options)
      host = options.fetch(:server)
      username = options.fetch(:username)
      command = options.fetch(:command)
      stdin = options.fetch(:stdin, "")
      # todo - :keys => filenames or :key_data => PEM id data
      response = {:stdout => "", :stderr => "", :start => Time.now.to_f}
      status = {}
      Net::SSH.start(host, username) do |ssh|
        response[:connected] = Time.now.to_f
        last_time = Time.now.to_f
        channel = ssh.exec command, status do |ch, stream, data|
          last_time = Time.now.to_f
          response[stream] << data
        end
        ssh.loop(0.5) { Time.now.to_f - last_time < 10.0 }
        channel.send_data(stdin)
        response[:last_out] = last_time
      end
      response[:finished] = Time.now.to_f
      response.merge(status)
    end

    def self.assert_response(request_definition, response, response_definition)
      response_definition.each do |option, value|
        case option
        when :exit_status
          if response[:exit_status] != value
            response.store(:failed, option)
            raise AssertionFailure.new(response), "Expected exit status of #{value} but got #{response[:exit_status].inspect}"
          end
        when :stdout
          value.each do |v|
            if ! response[:stdout].include?(v)
              response.store(:failed, option)
              raise AssertionFailure.new(response), "Expected stdout to include #{v.inspect}"
            end
          end
        end
      end
    end
  end

  class << self
    alias_method :run_without_ssh, :run

    def run(request_definition, response_definition)
      if request_definition[:type] == "ssh"
        response = Turd::SSH.request(request_definition)
        Turd::SSH.assert_response(request_definition, response, response_definition)
      else
        run_without_ssh(request_definition, response_definition)
      end
    end
  end
end
