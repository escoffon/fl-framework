FactoryBot.define do
  sequence(:list_counter) { |n| "#{n}" }

  factory :list, class: 'Fl::Framework::List::List' do
    transient do
      list_counter { generate(:list_counter) }
      objects { [ ] }
    end
    
    title { "list title - #{list_counter}" }
    caption { "list caption - #{list_counter}" }

    after(:build) do |list, evaluator|
      evaluator.objects.each do |o|
        case o
        when ActiveRecord::Base
          list.add_object(o)
        when Array
          list.add_object(o[0], o[1], o[2])
        when Hash
          list.add_object(o[:obj], o[:owner], o[:name])
        end          
      end
    end
  end
end
