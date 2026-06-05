# Pools

> **Note** — This gem was built for educational purposes to explore Ruby's
> concurrency primitives (threads, Ractors, `Ractor::Port`). It is not intended
> for production use. For production-grade thread pools, consider
> [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby).
>
> To use it locally: `gem "pools", github: "RDeckard/pools"` in your Gemfile,
> or `gem "pools", path: "/path/to/clone"` from a local clone.

Lightweight concurrency abstractions for Ruby. Two complementary pools:

- **`ThreadPool`** — a thread pool for **I/O-bound** work (HTTP calls, file
  downloads, DB queries). Threads share memory and a thread-safe queue; great
  when tasks spend their time *waiting*.
- **`RactorPool`** — a [Ractor](https://docs.ruby-lang.org/en/master/Ractor.html)
  pool for **CPU-bound** work (heavy computation). Ractors run in true
  parallelism, sidestepping the GVL; great when tasks spend their time
  *computing*.

> **Ruby version**
> `ThreadPool` works on any modern Ruby. `RactorPool`/`RactorWorker` rely on the
> `Ractor::Port` API and require **Ruby >= 4.0** (Ractors are still flagged
> experimental upstream).

## ThreadPool (I/O-bound work)

```ruby
thread_pool = Pools::ThreadPool.new(size: 4)

BUNCH_OF_URL_TO_DOWNLOAD.each do |file_to_download|
  thread_pool.schedule(file_to_download) do |file_to_download|
    # Runs in the background on one of the pool's threads
    DownloadService.new(file_to_download).perform # fictive service
  end
end

# Start the threads (4 here) and let them consume queued jobs in the background:
thread_pool.start # non-blocking
# ... do whatever you want ...
# NOTE: calling #start is optional — #wait will start the pool if needed.

# Close the queue and wait for all scheduled jobs to finish:
thread_pool.wait

# Every exception raised by a job is aggregated in `thread_pool.errors`
thread_pool.error_report
```

### Notes

- A thread pool can be `#start`ed before any job is scheduled: the threads
  simply wait for work.
- An empty queue doesn't mean the work is done (more jobs may be `#schedule`d
  later).
- Jobs can be `#schedule`d at any time while the queue is open.
- To close the queue, use `#wait` or `#terminate` (see below for the
  difference).
- If you don't `#wait` and the main thread exits before all jobs are done, the
  remaining jobs are lost.

### Lifecycle methods

| Method        | Behavior                                                            |
| ------------- | ------------------------------------------------------------------- |
| `#wait`       | Close the queue, then wait for **all** queued jobs to finish.       |
| `#terminate`  | Clear the queue, then wait only for the **currently running** jobs. |
| `#kill_all!`  | Kill every thread immediately, dropping running and queued jobs.    |

## RactorPool (CPU-bound work)

Workers can't *pull* from a shared queue (since Ruby 4.0 a `Ractor::Port` may
only be read by the Ractor that created it), so the pool *pushes* jobs to
workers round-robin and collects every outcome through a single output port.

A scheduled job names a constant that responds to `.perform(*args)`. The worker
resolves the constant on its side (constants are shared across Ractors), runs
it, and reports back.

```ruby
module Fibonacci
  def self.perform(n)
    a, b = 0, 1
    n.times { a, b = b, a + b }
    a
  end
end

pool = Pools::RactorPool.new(size: 4)
pool.start                          # non-blocking; spawns 4 worker Ractors

10.times { |n| pool.schedule("Fibonacci", n) }

pool.results
# => [ { ractor: 0, task: ["Fibonacci", [0]], result: 0 },
#      { ractor: 1, task: ["Fibonacci", [1]], result: 1 },
#      ... ]
```

Each outcome is a Hash carrying the worker id (`:ractor`), the original
`:task`, and either a `:result` or, if the job raised, an `:error` string. A
failing job never takes the pool down — its error is captured like any other
result.

`#wait` blocks until everything is done and returns the pool; `#results` does
the same and returns the collected outcomes (it's idempotent).

## RactorWorker (Sidekiq-like ergonomics)

`RactorWorker` wraps a `RactorPool` and gives your classes `.perform` /
`.perform_async` class methods, so a worker can run either inline or on the
pool:

```ruby
RWorker = Pools::RactorWorker.new(size: 4, verbose: true)

class HeavyWorker
  include RWorker

  def initialize(number)
    @number = number
  end

  def call
    (0..@number).sum
  end
end

RWorker.start
8.times { HeavyWorker.perform_async(10_000_000) }
RWorker.wait

RWorker.results.each { |outcome| puts outcome.inspect }

# Or run synchronously, in the current Ractor:
HeavyWorker.perform(10_000_000)
```

See [`examples/ractor_worker_example.rb`](examples/ractor_worker_example.rb)
for a runnable version.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can
also run `bin/console` for an interactive prompt to experiment.

Run the test suite with:

    $ bundle exec rspec

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/RDeckard/pools.
