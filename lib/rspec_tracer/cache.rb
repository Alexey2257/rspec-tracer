# frozen_string_literal: true

module RSpecTracer
  class Cache
    attr_reader :all_examples, :flaky_examples, :failed_examples, :pending_examples,
                :all_files, :dependency, :run_id

    def initialize
      @run_id = last_run_id
      @cache_dir = File.join(RSpecTracer.cache_path, @run_id) if @run_id

      @cached = false

      @all_examples = {}
      @flaky_examples = Set.new
      @failed_examples = Set.new
      @pending_examples = Set.new
      @all_files = {}
      @dependency = Hash.new { |hash, key| hash[key] = Set.new }
    end

    def load_cache_for_run
      return if @run_id.nil? || @cached

      starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      load_all_examples_cache
      load_flaky_examples_cache
      load_failed_examples_cache
      load_pending_examples_cache
      load_all_files_cache
      load_dependency_cache

      ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      @cached = true

      elpased = RSpecTracer::TimeFormatter.format_time(ending - starting)

      puts "RSpec tracer loaded cache from #{@cache_dir} (took #{elpased})"
    end

    def cached_examples_coverage
      return @examples_coverage if defined?(@examples_coverage)
      return @examples_coverage = {} if @run_id.nil?

      starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      coverage = load_examples_coverage_cache
      ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elpased = RSpecTracer::TimeFormatter.format_time(ending - starting)

      puts "RSpec tracer loaded cached examples coverage (took #{elpased})" if RSpecTracer.verbose?

      coverage
    end

    private

    def last_run_id
      file_name = File.join(RSpecTracer.cache_path, 'last_run.json')

      return unless File.file?(file_name)

      JSON.parse(File.read(file_name))['run_id']
    end

    def load_all_examples_cache
      file_name = File.join(@cache_dir, 'all_examples.json')

      return unless File.file?(file_name)

      @all_examples = JSON.parse(File.read(file_name)).transform_values do |examples|
        examples.transform_keys(&:to_sym)
      end

      @all_examples.each_value do |example|
        example[:execution_result].transform_keys!(&:to_sym)

        example[:run_reason] = nil
      end
    end

    def load_flaky_examples_cache
      file_name = File.join(@cache_dir, 'flaky_examples.json')

      return unless File.file?(file_name)

      @flaky_examples = JSON.parse(File.read(file_name)).to_set
    end

    def load_failed_examples_cache
      file_name = File.join(@cache_dir, 'failed_examples.json')

      return unless File.file?(file_name)

      @failed_examples = JSON.parse(File.read(file_name)).to_set
    end

    def load_pending_examples_cache
      file_name = File.join(@cache_dir, 'pending_examples.json')

      return unless File.file?(file_name)

      @pending_examples = JSON.parse(File.read(file_name)).to_set
    end

    def load_all_files_cache
      file_name = File.join(@cache_dir, 'all_files.json')

      return unless File.file?(file_name)

      @all_files = JSON.parse(File.read(file_name)).transform_values do |files|
        files.transform_keys(&:to_sym)
      end
    end

    def load_dependency_cache
      file_name = File.join(@cache_dir, 'dependency.json')

      return unless File.file?(file_name)

      @dependency = JSON.parse(File.read(file_name)).transform_values(&:to_set)
    end

    def load_examples_coverage_cache
      file_name = File.join(@cache_dir, 'examples_coverage.json')

      return unless File.file?(file_name)

      @examples_coverage = JSON.parse(File.read(file_name))
    end
  end
end
