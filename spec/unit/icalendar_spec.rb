require 'fl/framework/core'

RSpec.describe Fl::Framework::Core::HtmlHelper do
  # The local timezone for all tests is America/Los_Angeles

  before(:context) do
    @cur_tz = Time.zone
    Time.zone = 'America/Los_Angeles'
  end

  after(:context) do
    Time.zone = @cur_tz
  end

  def today(tz = nil)
    tzz = if tz.is_a?(String)
            ActiveSupport::TimeZone.new(tz)
          elsif tz.nil?
            Time.zone
          else
            tz
          end
    t = tzz.now
    sprintf('%04d%02d%02d', t.year, t.month, t.day)
  end

  describe 'datetime to Time conversion' do
    it 'should convert a Time object' do
      t = Time.now
      expect(Fl::Framework::Core::Icalendar.datetime_to_time(t).to_i).to eql(t.to_i)
    end
  end
end
