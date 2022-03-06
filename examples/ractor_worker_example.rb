# frozen_string_literal: true

puts "RUBY_VERSION: #{RUBY_VERSION}"

require_relative "../lib/ractor_worker"

RACTORS_COUNT = 4
VERBOSE       = true

# A custom module to include to all your worker class
RWorker = RactorWorker.new(size: RACTORS_COUNT, verbose: VERBOSE)

class AWorker
  # Adding AWorker.perform and AWorker.perform_async class method
  include RWorker

  def initialize(number)
    @number = number
  end

  def call
    output = (0..@number).lazy.reduce(0) { |acc, item| acc + item }

    # Threadsafe ouput
    RWorker.puts output
  end
end

# PROGRAM
start_at = Time.now

# Perform `RACTORS_COUNT * 2` tasks high CPU consuming in parallel
(RACTORS_COUNT * 2).times do
  AWorker.perform_async(10_000_000)
end
RWorker.wait

puts "It takes #{(Time.now - start_at).round(2)}s"
