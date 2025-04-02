require_relative("spec_helper")

module Hello
  def self.hello_name(name = nil)
    raise(ArgumentError, "'name' parameter is required") if name.nil?

    puts "Hello #{name}"
  end
end

RSpec.describe "My Plugin" do
  it "works" do
    expect(1).to eq(1)
  end

  it "shows exceptions" do
    Hello.hello_name
  end

  it "is pending"

  context "some context" do
    it "works" do
      puts "I'll pass"
      expect(1).to eq(1)
    end

    it "fails" do
      puts "I'll fail"
      expect(1).to eq(2)
    end

    it "raises" do
      raise(StandardError, "uh oh")
    end
  end
end
