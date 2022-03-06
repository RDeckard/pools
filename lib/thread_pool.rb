# frozen_string_literal: true

# --- DESCRIPTION ---
# An abstraction for Thread Pool. Useful for tasks that need to do bunch of I/O.
# - More efficient than poping threads by batch (see PR #5437)
# - Use a threadsafe queue and threadsafe errors collection
#
# Please see lib/tasks/maintenance/storage/download.rake as a concrete usage.

# --- USAGE EXAMPLE ---
# ``` ruby
# thread_pool = ThreadPool.new(size: 4)
#
# BUNCH_OF_URL_TO_DOWNLOAD.each do |file_to_download|
#   thread_pool.schedule(file_to_download) do |file_to_download|
#     # This block will be executed in background by a thread from the thread_pool
#     DownloadService.new(file_to_download).perform # fictive service
#   end
# end
#
# # Start the threads (4 here) and let them to consume queued jobs in background:
# thread_pool.start # non blocking operation
# # ... do whatever you want ...
# # NOTE: It is NOT mandatory to call #start as #wait will call it if it was not already called.
# # Close the queue and wait for all scheduled jobs to finish:
# thread_pool.wait
# # All exceptions collected by the threads are aggregated in `thread_pool.errors`
# ```

# --- NOTES ---
# - A thread pool can be #start even if no job was pushed in the queue yet: threads will just wait for jobs.
# - An empty job queue doesn't mean that work is done (maybe some jobs will be #schedule later?).
# - So jobs can be #schedule anytime while the queue is still open.
# - To close the queue, use #terminated or #wait (cf. below to see the differences)
# - If you don't #wait the thread_pool and the main thread exit before all jobs are done, all remaining jobs will be lost (knowing that #terminated call #wait too).
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
