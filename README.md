# Pools

 An abstraction for Thread Pool. Useful for tasks that need to do bunch of I/O.
 - More efficient than poping threads by batch
 - Use a threadsafe queue and threadsafe errors collection

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pools'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pools

## Usage

``` ruby
 thread_pool = ThreadPool.new(size: 4)

 BUNCH_OF_URL_TO_DOWNLOAD.each do |file_to_download|
   thread_pool.schedule(file_to_download) do |file_to_download|
     # This block will be executed in background by a thread from the thread_pool
     DownloadService.new(file_to_download).perform # fictive service
   end
 end

 # Start the threads (4 here) and let them to consume queued jobs in background:
 thread_pool.start # non blocking operation
 # ... do whatever you want ...
 # NOTE: It is NOT mandatory to call #start as #wait will call it if it was not already called.
 # Close the queue and wait for all scheduled jobs to finish:
 thread_pool.wait
 # All exceptions collected by the threads are aggregated in `thread_pool.errors`
 ```

 ### Note
 
 - A thread pool can be #start even if no job was pushed in the queue yet: threads will just wait for jobs.
 - An empty job queue doesn't mean that work is done (maybe some jobs will be #schedule later?).
 - So jobs can be #schedule anytime while the queue is still open.
 - To close the queue, use #terminated or #wait (cf. below to see the differences)
 - If you don't #wait the thread_pool and the main thread exit before all jobs are done, all remaining jobs will be lost (knowing that #terminated call #wait too).

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pools.
