require 'net/ssh'
require 'turd'

module Turd
  class SSH
    def self.request(request_definition)
      options = request_definition.fetch(:options)
      host = options.fetch(:server)
      username = options.fetch(:username)
      command = options.fetch(:command)
      stdin = options.fetch(:stdin, nil)
      # todo - :keys => filenames or :key_data => PEM id data
      response = {:stdout => "", :stderr => ""}
      started = Time.now.to_f
      connected = exited = stdout_started = nil
      Net::SSH.start(host, username) do |ssh|
        connected = Time.now.to_f
        ssh.open_channel do |channel|
          channel.exec(command) do |ch, success|
            if success
              channel.send_data(stdin) if stdin
              channel.eof!
              channel.on_request("exit-status") do |_, data|
                exited = Time.now.to_f
                response[:exit_status] = data.read_long
              end
              channel.on_data do |_, data|
                stdout_started = Time.now.to_f
                response[:stdout] << data
              end
            end
          end
        end
        ssh.loop
      end
      finished = Time.now.to_f
      response[:total_time] = finished - started
      response[:read_time] = exited - connected if exited and connected
      response[:sshauth_time] = connected - started if connected
      response
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
      response
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
