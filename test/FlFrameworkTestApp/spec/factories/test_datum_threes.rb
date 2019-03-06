FactoryBot.define do
  sequence(:datum_three_counter) { |n| "#{n}" }

  factory :test_datum_three do
    transient do
      datum_three_counter { generate(:datum_three_counter) }
    end
    
    title { "datum_three title.#{datum_three_counter}" }
    value { 3000 + datum_three_counter.to_i }
  end
end
