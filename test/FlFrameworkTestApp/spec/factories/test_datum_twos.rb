FactoryBot.define do
  sequence(:datum_two_counter) { |n| "#{n}" }

  factory :test_datum_two do
    transient do
      datum_two_counter { generate(:datum_two_counter) }
    end
    
    title { "datum_two title.#{datum_two_counter}" }
    value { "value: #{2000 + datum_two_counter.to_i}" }
  end
end
