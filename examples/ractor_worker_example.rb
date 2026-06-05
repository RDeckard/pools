# frozen_string_literal: true

puts "RUBY_VERSION: #{RUBY_VERSION}"

require_relative "../lib/pools"

POOL_SIZE  = 4
TASKS      = POOL_SIZE * 2
ITERATIONS = 5_000_000

def cpu_task(iterations)
  sum = 0.0
  i = 0
  while i < iterations
    sum += Math.sqrt(i)
    i += 1
  end
  sum.round(2)
end

puts "\n== Sequential (#{TASKS} tasks, 1 thread) =="
start_at = Time.now
TASKS.times { cpu_task(ITERATIONS) }
puts "#{(Time.now - start_at).round(2)}s"

puts "\n== ThreadPool (#{TASKS} tasks, #{POOL_SIZE} threads) =="
start_at = Time.now
pool = Pools::ThreadPool.new(size: POOL_SIZE)
TASKS.times { pool.schedule { cpu_task(ITERATIONS) } }
pool.wait
puts "#{(Time.now - start_at).round(2)}s"

puts "\n== RactorPool (#{TASKS} tasks, #{POOL_SIZE} ractors) =="

RWorker = Pools::RactorWorker.new(size: POOL_SIZE, verbose: false)

class CpuWorker
  include RWorker

  def initialize(iterations)
    @iterations = iterations
  end

  def call
    sum = 0.0
    i = 0
    while i < @iterations
      sum += Math.sqrt(i)
      i += 1
    end
    sum.round(2)
  end
end

RWorker.start
start_at = Time.now
TASKS.times { CpuWorker.perform_async(ITERATIONS) }
RWorker.wait
puts "#{(Time.now - start_at).round(2)}s"
