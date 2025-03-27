# frozen_string_literal: true

require("stringio")
require("json")
require("byebug")

RSpec.configure do |config|
  config.around(:each) do |example|
    original_stdout = $stdout
    $stdout = StringIO.new

    example.run

    example.metadata[:captured_stdout] = $stdout.string
  ensure
    $stdout = original_stdout
  end
end

module NSpect
  class JSONLFormatter
    RSpec::Core::Formatters.register self, :start, :example_passed, :example_failed, :example_pending

    def initialize(output)
      @output = output
    end

    def start(notification)
      @output << {
        sender: "nspect",
        type: "start",
        example_count: notification["count"],
      }.to_json
    end

    def example_passed(notification)
      @output << {
        sender: "nspect",
        type: "example_passed",
        absolute_filepath: notification.example.metadata[:absolute_file_path],
        small_filepath: notification.example.file_path,
        line_number: notification.example.metadata[:line_number],
        captured_stdout: notification.example.metadata[:captured_stdout],
      }.to_json
    end

    def example_failed(notification)
      @output << {
        sender: "nspect",
        type: "example_failed",
        absolute_filepath: notification.example.metadata[:absolute_file_path],
        small_filepath: notification.example.file_path,
        line_number: notification.example.metadata[:line_number],
        message_lines: notification.message_lines,
        captured_stdout: notification.example.metadata[:captured_stdout],
      }.to_json
    end

    def example_pending(notification)
      @output << {
        sender: "nspect",
        type: "example_pending",
        absolute_filepath: notification.example.metadata[:absolute_file_path],
        small_filepath: notification.example.file_path,
        line_number: notification.example.metadata[:line_number],
      }.to_json
    end
  end
end
