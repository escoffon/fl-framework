class CreateTestDatumOnes < ActiveRecord::Migration[5.0]
  def change
    create_table :test_datum_ones do |t|
      t.string :title
      t.references :owner

      t.timestamps
    end
  end
end
