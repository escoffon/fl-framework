class CreateTestDataModels < ActiveRecord::Migration[5.2]
  # These tables store objects to test models that hold data.
  # TestDatumOne and TestDatumTwo are listable
  # TestDatumThree is not listable

  def change
    create_table :test_datum_ones do |t|
      t.string		:title
      t.references	:owner
      t.integer		:value

      t.timestamps
    end
    
    create_table :test_datum_twos do |t|
      t.string		:title
      t.references	:owner
      t.string		:value

      t.timestamps
    end
    
    create_table :test_datum_threes do |t|
      t.string		:title
      t.references	:owner
      t.integer		:value

      t.timestamps
    end
    
    create_table :test_datum_fours do |t|
      t.string		:title
      t.references	:owner
      t.string		:value

      t.timestamps
    end
  end
end
