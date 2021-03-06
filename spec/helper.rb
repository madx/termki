require File.join(File.dirname(__FILE__), '..', 'lib', 'termki')
require 'bacon'

module Bacon
  module RedGreenOutput
    def handle_specification(name)
      puts name
      yield
      puts
    end

    def handle_requirement(description)
      error = yield
      if error.empty?
        puts "\e[32m+ #{description}\e[0m"
      else
        if error == "FAILED"
          puts "\e[31m- #{description}\e[0m"
        else
          puts "\e[35mE #{description}\e[0m"
        end
      end
    end

    def handle_summary
      print ErrorLog if Backtraces
      puts "%d specifications (%d requirements), %d failures, %d errors" %
        Counter.values_at(:specifications, :requirements, :failed, :errors)
    end
  end
end
