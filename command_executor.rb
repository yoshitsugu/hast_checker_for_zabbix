module CommandExecutor
  def exec_command_as_root(ssh, command)
    exec_status = :init
    result = ""
    exec_loop_count = 0
    channel = ssh.open_channel do |ch|
      channel.request_pty do |ch, success|
        raise "Could not obtain pty " if !success
      end
      channel.exec("su -") do |ch, success|
        raise "cannot exec 'su -'" unless success
        ch.on_data do |c, data|
          if exec_loop_count > @exec_max_num
            c.send_data "exit\n"
          end
          if data =~ /password/i
            channel.send_data "#{@config[:su_password]}\n"
            exec_status = :exec_as_root
          elsif data_is_prompt(data)
            if result.length > 0 && exec_status == :exec_command
              c.send_data "exit\n"
            end
            if exec_status == :exec_as_root
              c.send_data command.to_s + "\n"
              exec_status = :exec_command
            end
          else
            result += data if exec_status == :exec_command
          end
          exec_loop_count += 1
        end
      end
    end
    ssh.loop
    result
  end

  def data_is_prompt data
    data =~ /#/
  end
end
