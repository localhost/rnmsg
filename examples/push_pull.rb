#!/usr/bin/env ruby

require_relative '../ext/nmsg/nmsg'

addr = ARGV.shift || "inproc://6581"

Thread.abort_on_exception = true

@mutex = Mutex.new
@sent = @received = 0
@threads = []

MAX_MSG = 50

15.times do
  @mutex.synchronize do
    Thread.new do
      push = Nmsg::Socket.new(Nmsg::AF_SP, Nmsg::NN_PUSH)
      eid = push.connect(addr)
      loop do
        cnt = @mutex.synchronize { @sent += 1 }
        Thread.current.exit if cnt > MAX_MSG
        push.send_msg_block("#{Thread.current.object_id}: #{cnt}")
      end
    end
  end
end

pull = Nmsg::Socket.new(Nmsg::AF_SP, Nmsg::NN_PULL)
pull.bind addr

loop do
  ev = pull.poll Nmsg::NN_POLLIN, 50
  raise "Error: nn_poll" if ev.nil?
  if ev
    @received += 1
    puts "pulled data from thread #{pull.recv_msg}"
  else
    break if @received == MAX_MSG
  end
end

@threads.each &:join
pull.close
