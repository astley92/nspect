# frozen_string_literal: true

require("json")
require("byebug")

module NSpect
  class JSONLFormatter
    RSpec::Core::Formatters.register self, :start, :example_passed, :example_failed, :example_pending

    def initialize(output)
      @output = output
    end

    def start(notification)
      @output << {
        type: "start",
        example_count: notification["count"],
      }.to_json
    end

    def example_passed(notification)
      @output << {
        type: "example_passed",
        absolute_filepath: notification.example.metadata[:absolute_file_path],
        small_filepath: notification.example.file_path,
        line_number: notification.example.metadata[:line_number],
      }.to_json
    end

    def example_failed(notification)
      @output << {
        type: "example_failed",
        absolute_filepath: notification.example.metadata[:absolute_file_path],
        small_filepath: notification.example.file_path,
        line_number: notification.example.metadata[:line_number],
      }.to_json
    end

    def example_pending(notification)
      @output << {
        type: "example_pending",
        absolute_filepath: notification.example.metadata[:absolute_file_path],
        small_filepath: notification.example.file_path,
        line_number: notification.example.metadata[:line_number],
      }.to_json
    end
  end
end
