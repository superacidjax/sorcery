class CreateUsers < ActiveRecord::Migration::Current
  def self.up
    create_table :users do |t|
      t.string :username,         null: false
      t.string :email,            default: nil
      t.string :crypted_password
      t.string :salt

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :users
  end
end
