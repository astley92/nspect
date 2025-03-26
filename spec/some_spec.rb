require_relative("spec_helper")

RSpec.describe "My Plugin" do
  it "works" do
    expect(1).to eq(1)
  end

  context "some context" do
    it "works" do
      expect(1).to eq(1)
    end

    it "fails" do
      expect(1).to eq(2)
    end

    it "raises" do
      raise(NotImplementedError, "uh oh")
    end
  end

  it "is pending"
end
