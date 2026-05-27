# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paginator do
  describe "#initialize" do
    context "with empty params" do
      subject { Paginator.new({}) }

      it "sets page to 1" do
        expect(subject.page).to eq(1)
      end

      it "sets per_page to PER_PAGE_DEFAULT" do
        expect(subject.per_page).to eq(Paginator::PER_PAGE_DEFAULT)
      end

      it "sets page_offset to 0" do
        expect(subject.page_offset).to eq(0)
      end
    end

    context "with given params" do
      subject { Paginator.new({ page: 3, per_page: 10 }) }

      it "sets page to given value" do
        expect(subject.page).to eq(3)
      end

      it "sets per_page to given value" do
        expect(subject.per_page).to eq(10)
      end

      it "calculates page_offset as (page - 1) * per_page" do
        expect(subject.page_offset).to eq(20)
      end
    end

    describe "page edge cases" do
      it "handles page 0 as page 1" do
        expect(Paginator.new({ page: 0 }).page).to eq(1)
      end

      it "handles negative page as page 1" do
        expect(Paginator.new({ page: -10 }).page).to eq(1)
      end

      it "converts string page to integer" do
        expect(Paginator.new({ page: "2" }).page).to eq(2)
      end

      it "sets page_offset to 0 when page resolves to 1" do
        expect(Paginator.new({ page: 0 }).page_offset).to eq(0)
      end
    end

    describe "per_page edge cases" do
      it "handles per_page of 0 as PER_PAGE_DEFAULT" do
        expect(Paginator.new({ per_page: 0 }).per_page).to eq(Paginator::PER_PAGE_DEFAULT)
      end

      it "handles negative per_page as PER_PAGE_DEFAULT" do
        expect(Paginator.new({ per_page: -10 }).per_page).to eq(Paginator::PER_PAGE_DEFAULT)
      end

      it "converts string per_page to integer" do
        expect(Paginator.new({ per_page: "10" }).per_page).to eq(10)
      end

      it "caps per_page at PER_PAGE_MAXIMUM" do
        expect(Paginator.new({ per_page: 500 }).per_page).to eq(Paginator::PER_PAGE_MAXIMUM)
      end

      it "allows per_page equal to PER_PAGE_MAXIMUM" do
        expect(Paginator.new({ per_page: Paginator::PER_PAGE_MAXIMUM }).per_page).to eq(Paginator::PER_PAGE_MAXIMUM)
      end
    end

    describe "page_offset calculation" do
      it "returns 0 for page 1" do
        expect(Paginator.new({ page: 1, per_page: 10 }).page_offset).to eq(0)
      end

      it "returns per_page for page 2" do
        expect(Paginator.new({ page: 2, per_page: 10 }).page_offset).to eq(10)
      end

      it "calculates correctly for larger pages" do
        expect(Paginator.new({ page: 5, per_page: 20 }).page_offset).to eq(80)
      end
    end
  end

  describe "#total_pages" do
    subject { Paginator.new({}) }

    it "returns 1 when total is nil" do
      expect(subject.total_pages(nil)).to eq(1)
    end

    it "returns 1 when total is less than per_page" do
      expect(subject.total_pages(5)).to eq(1)
    end

    it "returns 1 when total equals per_page" do
      expect(subject.total_pages(Paginator::PER_PAGE_DEFAULT)).to eq(1)
    end

    it "rounds up for partial pages" do
      expect(subject.total_pages(21)).to eq(2)
    end

    it "returns correct page count for exact multiple" do
      expect(subject.total_pages(40)).to eq(2)
    end

    context "with custom per_page" do
      subject { Paginator.new({ per_page: 5 }) }

      it "calculates total pages correctly for exact multiple" do
        expect(subject.total_pages(25)).to eq(5)
      end

      it "returns 1 when total is less than per_page" do
        expect(subject.total_pages(4)).to eq(1)
      end

      it "rounds up for partial pages" do
        expect(subject.total_pages(11)).to eq(3)
      end
    end
  end
end
