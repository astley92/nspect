require_relative("spec_helper")

RSpec.describe "My Plugin" do
  it "works" do
    expect(1).to eq(1)
  end

  it "is invalid" do
    expect(1).to eq(2)
  end
end
