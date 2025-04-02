# frozen_string_literal: true

class ThreadPool
  attr_reader :size, :job_queue, :errors

  def initialize(size: 1, verbose: false)
    @size    = size
    @verbose = verbose

    @job_queue = Queue.new

    @errors = []
    @mutex  = Mutex.new
  end

  # Populate the pool with the number of threads indicated
  # in @size and make all threads waiting for jobs
  def start
    @pool = Array.new(@size) do
      Thread.new do
        # @job_queue.pop can  behave 3 ways:
        # 1. it returns next job available in the queue
        # 2. it wait for a new job if the @job_queue queue is empty
        # 3  it returns `nil` when @job_queue queue is closed AND empty (see the #close method below)
        while (job = @job_queue.pop)
          begin
            task, args = job

            task.call(*args)
          rescue => e # rubocop:disable Style/RescueStandardError
            @mutex.synchronize { @errors << { exception: e, task:, args: } }
          end
        end
      end
    end

    puts "--- Thread Pool started (#{@size} thread#{"s" unless @size == 1}) ---" if @verbose

    self
  end

  def schedule(*args, &block)
    @job_queue << [block, args]
  end

  # Close the job queue and wait for all remaining jobs to be done
  def wait
    start if @pool.nil?

    @job_queue.close # @job_queue.pop will return `nil` after all jobs are terminated
    @pool.each(&:join)
    puts "--- Thread Pool stopped ---" if @verbose
  end

  # Clear job queue and wait only for the running jobs to terminate
  def terminate
    @job_queue.clear
    wait
  end

  def kill_all!
    @pool&.each { |thread| Thread.kill(thread) }
    @job_queue.clear.close
  end

  def error_report
    puts "--- Thread Pool error report ---"
    if @errors.any?
      puts @errors
    else
      puts "no errors"
    end
  end
end
