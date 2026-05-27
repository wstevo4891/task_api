# frozen_string_literal: true

# ToDo: Add a spec for this class
class Paginator
  PER_PAGE_DEFAULT = 20
  PER_PAGE_MAXIMUM = 100

  attr_reader :page, :per_page, :page_offset

  def initialize(params)
    @params = params
    @page = calc_page
    @per_page = calc_per_page
    @page_offset = (page - 1) * per_page
  end

  def total_pages(total_results)
    return 1 if total_results.blank?

    (total_results.to_f / per_page).ceil
  end

  private

  attr_reader :params

  def calc_page
    page_param = params[:page].to_i
    page_param <= 0 ? 1 : page_param
  end

  def calc_per_page
    per_page_param = params[:per_page].to_i

    if per_page_param <= 0
      PER_PAGE_DEFAULT
    else
      [ per_page_param, PER_PAGE_MAXIMUM ].min
    end
  end
end
