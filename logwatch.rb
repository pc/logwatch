require 'rubygems'
require 'tmail'
require 'net/smtp'

class LogWatch
  def size; File.stat(@path).size; end
  def update_size; @size = size; end
  def last_size; @size; end
  
  def initialize(path, to, from="logwatch@#{`hostname`.strip}")
    @path = path
    @to = to
    @from = from

    if exists?
      @size = size
    else
      @size = 0
    end
  end
  
  def diff(sz)
    File.open(@path, 'r') do |f|
      f.seek(last_size)
      f.read(sz - last_size)
    end
  end
  
  def mail(diff)
    m = TMail::Mail.new
    m.to = @to
    m.from = @from
    m.body = diff
    m.subject = "Change in #{@path}"
    m.date = Time.now

    Net::SMTP.start('localhost', 25) {|cli| cli.send_message(m.to_s, @from, @to)}
  end

  def exists?; File.exists?(@path); end

  def announce
    $stderr.puts "Watching #{@path}"
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
