FactoryBot.define do
  sequence(:datum_four_counter) { |n| "#{n}" }

  factory :test_datum_four do
    transient do
      datum_four_counter { generate(:datum_four_counter) }
    end
    
    title { "datum_four title.#{datum_four_counter}" }
    value { "value: #{2000 + datum_four_counter.to_i}" }
  end
end
