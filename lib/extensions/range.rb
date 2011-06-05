class Range
  def to_parser
    Rubec::choice(*(self).map(&:to_s).map(&:to_parser))
  end
end
