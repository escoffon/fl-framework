class CreateTestActors < ActiveRecord::Migration[5.0]
  def change
    create_table :test_actors do |t|
      t.string :name

      t.timestamps
    end
  end
end
