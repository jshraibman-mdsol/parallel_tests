module ParallelTests
  class Grouper
    def self.in_groups(items, num_groups)
      groups = Array.new(num_groups){ [] }

      until items.empty?
        num_groups.times do |group_number|
          if item = items.shift
            groups[group_number] << item
          end
        end
      end

      groups.map!(&:sort!)
    end

    def self.in_even_groups_by_size(items_with_sizes, num_groups, options={})
      groups = Array.new(num_groups){{:items => [], :size => 0}}

      # add all files that should run in a single process to one group
      (options[:single_process]||[]).each do |pattern|
        matched, items_with_sizes = items_with_sizes.partition{|item, size| item =~ pattern }
        smallest = smallest_group(groups)
        matched.each{|item,size| add_to_group(smallest, item, size) }
      end

      # add all other files
      largest_first(items_with_sizes).each do |item, size|
        smallest = smallest_group(groups)
        add_to_group(smallest, item, size)
      end

      groups.map!{|g| g[:items].sort }
    end

    def self.largest_first(files)
      files.sort_by{|item, size| size }.reverse
    end

    private

    def self.smallest_group(groups)
      groups.min_by{|g| g[:size] }
    end

    def self.add_to_group(group, item, size)
      group[:items] << item
      group[:size] += size
    end

    def self.by_tags(test_files, num_groups)
      #TODO: factor out common code
      require 'parallel_tests/cucumber/gherkin_listener'
      listener = Cucumber::GherkinListener.new
      parser = Gherkin::Parser::Parser.new(listener, true, 'root')
      test_files.each{|file|
        parser.parse(File.read(file), file, 0)
      }
      #TODO: make regex an option
      pbs = listener.tags.grep(/@PB.*/)
      pbs.uniq!
      pbs.shuffle!
      split_arr_in_groups(pbs, num_groups)
    end

    def self.split_arr_in_groups(arr, num_groups)
      return arr.map { |s| [s] } if arr.length <= num_groups
      num_in_each_group = arr.length / num_groups
      remainder = arr.length % num_groups
      groups = []
      lower_bound = 0
      (1..num_groups).each do |group_idx|
        upper_bound = lower_bound + num_in_each_group
        upper_bound +=1 if group_idx <= remainder
        groups << arr[lower_bound...upper_bound]
        lower_bound = upper_bound
      end
      groups
    end


    def self.by_steps(tests, num_groups)
      features_with_steps = build_features_with_steps(tests)
      in_even_groups_by_size(features_with_steps, num_groups)
    end

    def self.build_features_with_steps(tests)
      require 'parallel_tests/cucumber/gherkin_listener'
      listener = Cucumber::GherkinListener.new
      parser = Gherkin::Parser::Parser.new(listener, true, 'root')
      tests.each{|file|
        parser.parse(File.read(file), file, 0)
      }
      listener.collect.sort_by{|_,value| -value }
    end
  end
end
