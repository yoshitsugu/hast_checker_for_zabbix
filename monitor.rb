require 'rubygems'
require 'logger'
require 'net/ssh'

require File.dirname(__FILE__) + "/config"
require File.dirname(__FILE__) + "/command_executor"
# CONFIG = {
#   :host => "nas4free.example.com",
#   :user => "username",
#   :pass => {:password/:passphrase => "password"},
#   :su_password => "password for su"},
#   :logger => "/tmp/logger.log",
#   :hast_names => [["hast1", "primary"], ["hast2", "secondary"]]
# }

EXEC_MAX_NUM = 30

class Monitor
  include CommandExecutor

  def initialize
    @config = CONFIG
    @logger = Logger.new(@config[:logger])
    @exec_max_num = EXEC_MAX_NUM
  end

  def ssh_login 
    Net::SSH.start(@config[:host], @config[:user], @config[:pass]) do |ssh|
      yield(ssh)
    end
  end

  def get_hast_status(ssh, hast_name)
    @hast_status = exec_command_as_root(ssh, "hastctl status #{hast_name}")
  end

  def check_hast ssh
    is_valid = @config[:hast_names].inject(true) do |result, data|
      hast_name = data[0]
      role = data[1]
      get_hast_status(ssh, hast_name)
      info(@hast_status)
      result &&= check_hast_status(role)
    end
    puts is_valid ? "1": "0"
  end

  def check_hast_status(role)
    @hast_status =~ /status: complete/ && @hast_status =~ /role: #{role}/
  end

  def info i
    @logger.info i
  end

  def error e
    @logger.error e.message
    @logger.error e.backtrace.join("\n")
  end
  
  def main
    begin
      ssh_login do |ssh|
        check_hast(ssh)
      end
    rescue => e
      error(e)
    end
  end
end

Monitor.new.main

