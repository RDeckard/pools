# frozen_string_literal: true

require_relative "pools/version"
require_relative "pools/thread_pool"
require_relative "pools/ractor_pool"
require_relative "pools/ractor_worker"

module Pools
  class Error < StandardError; end
end
