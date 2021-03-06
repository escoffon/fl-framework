class CreateTestActors < ActiveRecord::Migration[5.2]
  def change
    # Object used for testing actors and owners.
    
    create_table :test_actors do |t|
      t.string		:name

      t.timestamps
    end

    # Another actor to test actor support
    
    create_table :test_actor_twos do |t|
      t.string		:name

      t.timestamps
    end
  end
end
