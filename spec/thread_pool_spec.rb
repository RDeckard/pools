# frozen_string_literal: true

require "thread_pool"

describe ThreadPool do
  subject(:thread_pool) { described_class.new } # Default: one background thread

  describe "global behavior" do
    context "when using #start, #shedule and #wait correctly" do
      it "finishes all passed jobs" do
        array = []

        thread_pool.schedule { array << "first job" } # non blocking operation

        thread_pool.start # start consuming queued jobs (non blocking operation)

        # We can produce new jobs even after starting the thread pool
        thread_pool.schedule { array << "second job" }

        thread_pool.wait # wait for all jobs to be done (BLOCKING operation)

        expect(array).to contain_exactly "first job", "second job"
      end
    end
  end

  describe "usage" do
    context "with 4 I/O jobs" do
      # assuming that `sleep` behave like a I/O job from the "non-blocking" point of view
      let(:sleep_durations) { [0.1, 0.2, 0.4, 0.3] }

      context "with 1 thread" do
        it "takes the sum of all durations to do all jobs" do
          sleep_durations.each do |sleep_duration|
            thread_pool.schedule(sleep_duration) { sleep sleep_duration }
          end

          start_at = Time.now
          thread_pool.wait # see below: #wait also #start the thread pool if it wasn't already
          truncate_elapse_time = (Time.now - start_at).round(1)

          expect(truncate_elapse_time).to eq 1.0
        end
      end

      context "with 4 threads" do
        subject(:thread_pool) { described_class.new(size: 4) }

        it "takes only the longest duration to do all jobs" do
          sleep_durations.each do |sleep_duration|
            thread_pool.schedule(sleep_duration) { sleep sleep_duration }
          end

          start_at = Time.now
          thread_pool.wait
          truncate_elapse_time = (Time.now - start_at).round(1)

          expect(truncate_elapse_time).to eq 0.4
        end
      end
    end
  end

  describe "#start and #schedule" do
    after do
      # In the context of this test, kill the long task
      thread_pool.kill_all!
    end

    it "are non blocking operations" do
      start_at = Time.now

      thread_pool.schedule { sleep 10 } # a long task
      thread_pool.start

      elapse_time = Time.now - start_at
      expect(elapse_time.to_i).to eq 0
    end
  end

  describe "#start" do
    it "consumes the job queue" do
      expect(thread_pool.job_queue).to be_empty

      thread_pool.schedule { "a job" }
      expect(thread_pool.job_queue.size).to eq 1

      thread_pool.start
      sleep 0.1
      expect(thread_pool.job_queue).to be_empty
    end
  end

  describe "#schedule" do
    it "adds jobs in the #job_queue" do
      expect(thread_pool.job_queue).to be_empty

      thread_pool.schedule { "a job" }
      expect(thread_pool.job_queue.size).to eq 1
    end
  end

  describe "#wait" do
    context "without having called `thread_pool.start` before" do
      it "calls #start" do
        expect(thread_pool).to receive(:start).and_call_original # rubocop:disable RSpec/SubjectStub

        thread_pool.wait
      end
    end

    it "waits until all scheduled jobs are done" do
      array = []

      thread_pool.schedule do
        sleep 0.1
        array << "first job"
      end
      thread_pool.schedule do
        sleep 0.1
        array << "last job"
      end
      expect(thread_pool.job_queue.size).to eq 2

      expect(array).to be_empty # jobs didn't have the time to finish

      thread_pool.wait
      expect(thread_pool.job_queue).to be_empty
      expect(array).to contain_exactly "first job", "last job"
    end

    it "prevents any new job to be scheduled" do
      thread_pool.wait

      expect { thread_pool.schedule { "a new job" } }.to raise_exception ClosedQueueError
    end
  end

  shared_examples "a method that clear the queue" do |method|
    it "clears the job queue without executing any queued job" do
      array = []

      expect(thread_pool.job_queue).to be_empty

      thread_pool.schedule { array << "a job" }
      expect(thread_pool.job_queue.size).to eq 1

      thread_pool.public_send(method)
      expect(array).to be_empty
      expect(thread_pool.job_queue).to be_empty
    end
  end

  describe "#terminate" do
    it_behaves_like "a method that clear the queue", :terminate

    it "calls #wait" do
      expect(thread_pool).to receive(:wait).and_call_original # rubocop:disable RSpec/SubjectStub

      thread_pool.terminate
    end

    it "waits only for the current running jobs" do
      thread_pool.start

      array = []

      expect(thread_pool.job_queue).to be_empty

      thread_pool.schedule do
        sleep 0.1
        array << "first job"
      end
      expect(thread_pool.job_queue.size).to eq 1

      sleep 0.05 # lets the first job to be started
      expect(thread_pool.job_queue).to be_empty

      thread_pool.schedule do # non blocking operation...
        sleep 0.1
        array << "last job"
      end
      expect(thread_pool.job_queue.size).to eq 1
      expect(array).to be_empty # ... so no jobs didn't have the time to finish

      thread_pool.terminate # clears the queue but waits for the first job to finish
      expect(thread_pool.job_queue).to be_empty
      expect(array).to contain_exactly "first job"
    end

    it "prevents any new job to be scheduled" do
      thread_pool.terminate

      expect { thread_pool.schedule { "a new job" } }.to raise_exception ClosedQueueError
    end
  end

  describe "#kill_all!" do
    it_behaves_like "a method that clear the queue", :kill_all!

    it "kills all threads without letting them finish their current jobs" do
      thread_pool.start

      array = []

      expect(thread_pool.job_queue).to be_empty

      thread_pool.schedule do
        sleep 0.1
        array << "first job"
      end
      expect(thread_pool.job_queue.size).to eq 1

      sleep 0.05 # let the first job to be started
      expect(thread_pool.job_queue).to be_empty

      thread_pool.schedule do # non blocking operation...
        sleep 0.1
        array << "last job"
      end
      expect(thread_pool.job_queue.size).to eq 1
      expect(array).to be_empty # ... so no jobs didn't have the time to finish

      thread_pool.kill_all! # clear the queue but wait for the first job to finish
      expect(thread_pool.job_queue).to be_empty
      expect(array).to be_empty
    end

    it "prevents any new job to be scheduled" do
      thread_pool.terminate

      expect { thread_pool.schedule { "a new job" } }.to raise_exception ClosedQueueError
    end
  end
end
