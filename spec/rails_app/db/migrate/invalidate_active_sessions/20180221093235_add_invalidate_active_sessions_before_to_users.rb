class AddInvalidateSessionsBeforeToUsers < ActiveRecord::Migration::Current
  def self.up
    add_column :users, :invalidate_sessions_before, :datetime, default: nil
  end

  def self.down
    remove_column :users, :invalidate_sessions_before
  end
end
