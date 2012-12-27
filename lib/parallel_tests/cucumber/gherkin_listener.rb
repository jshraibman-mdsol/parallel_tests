require 'gherkin'

module ParallelTests
  module Cucumber
    class GherkinListener
      attr_reader :collect, :tags
      # There must be at least one tag per scenario that matchers this pattern.  Any ones after the first one are
      # ignored.  If there are zero an error is thrown
      attr_writer :uniq_tag_pattern
      # When collecting tags ignore scenarios with tags that match this pattern
      attr_writer :ignore_tag_pattern

      def initialize
        @steps, @uris = [], []
        @collect = {}
        @tags = []
        reset_counters!
      end

      def feature(feature)
        @feature = feature
      end

      def background(*args)
        @background = 1
      end

      def scenario(scenario)
        count_tags(scenario)
        @scenarios += 1
        @outline = @background = 0
      end

      private
      def count_tags(scenario)
        all_tags = (scenario.tags || []) + ((@feature && @feature.tags) || [])
        return if @ignore_tag_pattern && all_tags.find{ |tag| @ignore_tag_pattern === tag.name }

        if @uniq_tag_pattern
           found_tags = scenario.tags.map { |tag| tag.name }.grep(@uniq_tag_pattern)
          if found_tags.length > 0
            @tags << found_tags[0]
          else
            raise %Q{Scenario "#{ scenario.name } @ #{ @uri }:#{ scenario.line } does not have a tag that matches #{ @uniq_tag_pattern }" }
          end

        else
          # Collect all tags in this case
          scenario.tags.each { |tag| @tags << tag.name }
        end
      end

      public

      def scenario_outline(outline)
        count_tags(outline)
        @outline = 1
      end

      def step(*args)
        if @background == 1
          @background_steps += 1
        elsif @outline > 0
          @outline_steps += 1
        else
          @collect[@uri] += 1
        end
      end

      def uri(path)
        @uri = path
        @collect[@uri] = 0
      end

      def examples(*args)
        @examples += 1
      end

      def eof(*args)
        @collect[@uri] += (@background_steps * @scenarios) + (@outline_steps * @examples)
        reset_counters!
      end

      def reset_counters!
        @examples = @outline = @outline_steps = @background = @background_steps = @scenarios = 0
      end

      # ignore lots of other possible callbacks ...
      def method_missing(*args)
      end
    end
  end
end
