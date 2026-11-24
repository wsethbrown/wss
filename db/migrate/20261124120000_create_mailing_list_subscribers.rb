# People who asked to be told when a new deck is published (the "deck news"
# sign-up on the library and deck pages). Not a paid membership: no account is
# needed. A row is on the list only once its address is confirmed from the
# emailed link and it has not unsubscribed (MailingListSubscriber.active).
# Only an HMAC digest of the confirm token is stored.
class CreateMailingListSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :mailing_list_subscribers do |t|
      t.string :email, null: false
      t.string :confirmation_token_digest
      t.datetime :confirmation_sent_at
      t.datetime :confirmed_at
      t.datetime :unsubscribed_at
      t.string :source, limit: 30

      t.timestamps
    end

    add_index :mailing_list_subscribers, :email, unique: true
    add_index :mailing_list_subscribers, :confirmation_token_digest, unique: true
  end
end
