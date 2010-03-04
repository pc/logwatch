#!/usr/bin/env ruby

require 'rubygems'
require 'tmail'
require 'net/smtp'
require 'tempfile'

class LogWatch
  def size
    update_cmd if @cmd
    File.stat(path).size
  end

  def path; @cmd ? cmd_path : @path; end
  def thing; @cmd ? @cmd : @path; end

  def update_cmd
    File.open(cmd_path, 'w') {|f| f.write(`#{@cmd}`)}
  end

  def cmd_path; @cmd_path ||= Tempfile.new(__FILE__).path; end

  def update_size; @size = size; end
  def last_size; @size; end
  
  def initialize(path_or_cmd, to, from="logwatch@#{`hostname`.strip}")
    @to = to
    @from = from

    if path_or_cmd =~ /^!/
      @cmd = path_or_cmd[1..-1]
      update_cmd
    else
      @path = path_or_cmd
    end

    if exists?
      @size = size
    else
      @size = 0
    end
  end
  
  def diff(sz)
    File.open(path, 'r') do |f|
      f.seek(last_size)
      f.read(sz - last_size)
    end
  end
  
  def mail(diff)
    m = TMail::Mail.new
    m.to = @to
    m.from = @from
    m.body = diff
    m.subject = "Change in #{path}"
    m.date = Time.now

    Net::SMTP.start('localhost', 25) {|cli| cli.send_message(m.to_s, @from, @to)}
  end

  def exists?; File.exists?(path); end

  def announce
    $stderr.puts "Watching #{thing}"
  end
  
  def watch
    announce

    loop do
      if exists?
        s = size

        if s > last_size
          mail(diff(s))
          @size = s
        elsif s < last_size
          $stderr.puts "I expect an append-only file; file size just decreased. I give up."
          exit 1
        end
      end
      
      sleep 5
    end
  end
end

if $0 == __FILE__
  LogWatch.new(*ARGV).watch
end
