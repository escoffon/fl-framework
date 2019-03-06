FactoryBot.define do
  sequence(:datum_one_counter) { |n| "#{n}" }

  factory :test_datum_one do
    transient do
      datum_one_counter { generate(:datum_one_counter) }
    end
    
    title { "datum_one title.#{datum_one_counter}" }
    value { 1000 + datum_one_counter.to_i }
  end
end
