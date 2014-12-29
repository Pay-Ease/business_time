require File.expand_path('../helper', __FILE__)

describe "time extensions" do
  it "know a weekend day is not a workday" do
    assert( Time.workday?(Time.parse("April 9, 2010 10:45 am")))
    assert(!Time.workday?(Time.parse("April 10, 2010 10:45 am")))
    assert(!Time.workday?(Time.parse("April 11, 2010 10:45 am")))
    assert( Time.workday?(Time.parse("April 12, 2010 10:45 am")))
  end

  it "know a weekend day is not a workday (with a configured work week)" do
    BusinessTime::Config.work_week = %w[sun mon tue wed thu]
    assert( Time.weekday?(Time.parse("April 8, 2010 10:30am")))
    assert(!Time.weekday?(Time.parse("April 9, 2010 10:30am")))
    assert(!Time.weekday?(Time.parse("April 10, 2010 10:30am")))
    assert( Time.weekday?(Time.parse("April 11, 2010 10:30am")))
  end

  it "know a holiday is not a workday" do
    BusinessTime::Config.holidays << Date.parse("July 4, 2010")
    BusinessTime::Config.holidays << Date.parse("July 5, 2010")

    assert(!Time.workday?(Time.parse("July 4th, 2010 1:15 pm")))
    assert(!Time.workday?(Time.parse("July 5th, 2010 2:37 pm")))
  end

  it "know a holiday is not a workday for region" do
    BusinessTime.region :ca do
      holiday = Time.parse("July 1, 2008 14:00")  # Holiday in Canada
      assert !Time.workday?(holiday)
    end
  end

  it "know the beginning of the day for an instance" do
    first = Time.parse("August 17th, 2010, 11:50 am")
    expecting = Time.parse("August 17th, 2010, 9:00 am")
    assert_equal expecting, Time.beginning_of_workday(first)
  end

  it "know the end of the day for an instance" do
    first = Time.parse("August 17th, 2010, 11:50 am")
    expecting = Time.parse("August 17th, 2010, 5:00 pm")
    assert_equal expecting, Time.end_of_workday(first)
  end

  # ===================

  it "calculate business time between different times on the same date (clockwise)" do
    time_a = Time.parse('2012-02-01 10:00')
    time_b = Time.parse('2012-02-01 14:20')
    assert_equal time_a.business_time_until(time_b), 260.minutes
  end

  it "calculate business time between different times on the same date (counter clockwise)" do
    time_a = Time.parse('2012-02-01 10:00')
    time_b = Time.parse('2012-02-01 14:20')
    assert_equal time_b.business_time_until(time_a), -260.minutes
  end

  it "calculate business time only within business hours even if second endpoint is out of business time" do
    time_a = Time.parse('2012-02-01 10:00')
    time_b = Time.parse("2012-02-01 " + BusinessTime::Config.end_of_workday) + 24.minutes
    first_result = time_a.business_time_until(time_b)
    time_b = Time.parse('2012-02-01 '+ BusinessTime::Config.end_of_workday)
    second_result = time_a.business_time_until(time_b)
    assert_equal first_result, second_result
    assert_equal first_result, 7.hours
  end

  it "calculate business time only within business hours even if the first endpoint is out of business time" do
    time_a = Time.parse("2012-02-01 7:25")
    time_b = Time.parse("2012-02-01 15:30")
    first_result = time_a.business_time_until(time_b)
    assert_equal first_result, 390.minutes
  end

  it "return correct time between two consecutive days" do
    time_a = Time.parse('2012-02-01 10:00')
    time_b = Time.parse('2012-02-02 10:00')
    working_hours = Time.parse(BusinessTime::Config.end_of_workday) - Time.parse(BusinessTime::Config.beginning_of_workday)
    assert_equal time_a.business_time_until(time_b), working_hours
  end

  it "calculate proper timing if there are several days between" do
    time_a = Time.parse('2012-03-01 10:00')
    time_b = Time.parse('2012-03-09 11:00')
    duration_of_working_day = Time.parse(BusinessTime::Config.end_of_workday) - Time.parse(BusinessTime::Config.beginning_of_workday)
    assert_equal time_a.business_time_until(time_b), 6 * duration_of_working_day + 1.hour
    assert_equal time_b.business_time_until(time_a), -(6 * duration_of_working_day + 1.hour)
  end

  it "calculate proper duration even if the end date is on a weekend" do
    ticket_reported = Time.parse("February 3, 2012, 10:40 am")
    ticket_resolved = Time.parse("February 4, 2012, 10:40 am") #will roll over to Monday morning, 9:00am
    assert_equal ticket_reported.business_time_until(ticket_resolved), 6.hours + 20.minutes
  end

  it "knows if within business hours" do
    assert(Time.parse("2013-02-01 10:00").during_business_hours?)
    assert(!Time.parse("2013-02-01 5:00").during_business_hours?)
  end

  # =================== .roll_backward ======================

  it "roll to the end of the same day when after hours on a workday" do
    time = Time.parse("11pm UTC, Wednesday 9th May, 2012")
    workday_end = BusinessTime::Config.end_of_workday
    expected_time = Time.parse("#{workday_end} UTC, Wednesday 9th May, 2012")
    assert_equal Time.roll_backward(time), expected_time
  end

  it "roll to the end of the previous day when before hours on a workday" do
    time = Time.parse("04am UTC, Wednesday 9th May, 2012")
    workday_end = BusinessTime::Config.end_of_workday
    expected_time = Time.parse("#{workday_end} UTC, Tuesday 8th May, 2012")
    assert_equal Time.roll_backward(time), expected_time
  end

  it "rolls to the end of the previous workday on non-working days" do
    time = Time.parse("12pm UTC, Sunday 6th May, 2012")
    workday_end = BusinessTime::Config.end_of_workday
    expected_time = Time.parse("#{workday_end} UTC, Friday 4th May, 2012")
    assert_equal Time.roll_backward(time), expected_time
  end

  it "returns the given time during working hours" do
    time = Time.parse("12pm, Tuesday 8th May, 2012")
    assert_equal Time.roll_backward(time), time
  end

  it "respects work hours" do
    wednesday = Time.parse("December 22, 2010 12:00")
    saturday  = Time.parse("December 25, 2010 12:00")
    BusinessTime::Config.work_hours = {
      :wed=>["9:00","12:00"],
      :sat=>["13:00","14:00"]
    }
    assert_equal wednesday, Time.roll_backward(saturday)
  end

  # =================== sequences ======================

  it "starts next day at the morning" do
    monday = Time.parse("July 7, 2008 14:00")
    tuesday_morning = Time.parse("July 8, 2008 9:00")
    assert_equal tuesday_morning, monday.next_business_day
  end

  it "save timezone" do
    day = Time.parse("Tue, 23 Dec 2014 13:55:10 -09:00").in_time_zone('Alaska')
    next_day = Time.parse("Tue, 24 Dec 2014 09:00:00 -09:00").in_time_zone('Alaska')
    assert_equal next_day, day.next_business_day
  end

  it "starts previous day at the morning" do
    tuesday = Time.parse("July 3, 2008 14:00")
    wednesday_morning = Time.parse("July 2, 2008 9:00")
    assert Time.workday?(wednesday_morning)
    assert_equal wednesday_morning, tuesday.previous_business_day
  end

  it "returns first working day after holiday" do
    BusinessTime.company :us do
      sunday = Time.parse('Fri, 28 Dec 2014 04:00')
      monday = Time.parse('Fri, 29 Dec 2014 09:00')
      assert_equal monday, sunday.next_business_day
    end
  end

  it "returns first working day before holiday" do
    BusinessTime.company :us do
      saturday = Time.parse('Fri, 13 Dec 2014 04:00')
      friday = Time.parse('Fri, 12 Dec 2014 09:00')
      assert_equal friday, saturday.previous_business_day
    end
  end

  # =================== working time ======================

  it "ability to setup config for different companies" do
    yaml = <<-YAML
      business_time:
        my_company:
          beginning_of_workday: 7:00 am
          end_of_workday: 2:00 pm
    YAML
    config_file = StringIO.new(yaml.gsub!(/^    /, ''))
    BusinessTime::Config.load_companies(config_file)

    BusinessTime.company :my_company do
      assert_equal "7:00 am", BusinessTime::Config.beginning_of_workday
      assert_equal "2:00 pm", BusinessTime::Config.end_of_workday
    end
  end

  it "supports special dates" do
    yaml = <<-YAML
      business_time:
        us:
          beginning_of_workday: 7:00 am
          end_of_workday: 2:00 pm
          special_days:
            "24 Dec 2014":
              beginning_of_workday: 7:00 am
              end_of_workday: 4:00 pm
    YAML
    config_file = StringIO.new(yaml.gsub!(/^    /, ''))
    BusinessTime::Config.load_companies(config_file)

    BusinessTime.company :us do
      assert_equal "2:00 pm", BusinessTime::Config.end_of_workday
      day = Date.parse("24 Dec 2014")
      end_of_workday = Time.parse("2014-12-24 16:00:00 +0300")
      assert_equal end_of_workday, Time.end_of_workday(day)

      time = Time.parse("2014-12-24 14:50:00 +0300")
      expected = Time.parse("2014-12-24 15:50:00 +0300")
      assert_equal expected, 1.business_hour.after(time)

      time = Time.parse("2014-12-23 14:50:00 +0300")
      expected = Time.parse("2014-12-24 8:00:00 +0300")
      assert_equal expected, 1.business_hours.after(time)
    end
  end
end
