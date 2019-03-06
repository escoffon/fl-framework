FactoryBot.define do
  sequence(:actor_counter) { |n| "#{n}" }

  factory :test_actor do
    transient do
      actor_counter { generate(:actor_counter) }
    end
    
    name { "actor.#{actor_counter}" }
  end
end
