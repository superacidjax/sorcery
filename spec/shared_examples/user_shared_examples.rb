shared_examples_for 'rails_3_core_model' do
  let(:user) { create_new_user }
  let(:crypted_password) { user.send User.sorcery_config.crypted_password_attribute_name }

  describe 'loaded plugin configuration' do
    after(:each) { User.sorcery_config.reset! }

    it "enables configuration option 'username_attribute_names'" do
      sorcery_model_property_set(:username_attribute_names, :email)

      expect(User.sorcery_config.username_attribute_names).to eq [:email]
    end

    it "enables configuration option 'password_attribute_name'" do
      sorcery_model_property_set(:password_attribute_name, :mypassword)

      expect(User.sorcery_config.password_attribute_name).to eq :mypassword
    end

    it "enables configuration option 'email_attribute_name'" do
      sorcery_model_property_set(:email_attribute_name, :my_email)

      expect(User.sorcery_config.email_attribute_name).to eq :my_email
    end

    it "enables configuration option 'crypted_password_attribute_name'" do
      sorcery_model_property_set(:crypted_password_attribute_name, :password)

      expect(User.sorcery_config.crypted_password_attribute_name).to eq :password
    end

    it "enables configuration option 'salt_attribute_name'" do
      sorcery_model_property_set(:salt_attribute_name, :my_salt)

      expect(User.sorcery_config.salt_attribute_name).to eq :my_salt
    end

    it "enables configuration option 'encryption_algorithm'" do
      sorcery_model_property_set(:encryption_algorithm, :none)

      expect(User.sorcery_config.encryption_algorithm).to eq :none
    end

    it "enables configuration option 'encryption_key'" do
      sorcery_model_property_set(:encryption_key, 'asdadas424234242')

      expect(User.sorcery_config.encryption_key).to eq 'asdadas424234242'
    end

    it "enables configuration option 'custom_encryption_provider'" do
      sorcery_model_property_set(:encryption_algorithm, :custom)
      sorcery_model_property_set(:custom_encryption_provider, Array)

      expect(User.sorcery_config.custom_encryption_provider).to eq Array
    end

    it "enables configuration option 'pepper'" do
      pepper = '*$%&%*++'
      sorcery_model_property_set(:pepper, pepper)

      expect(User.sorcery_config.pepper).to eq pepper
    end

    it "enables configuration option 'salt_join_token'" do
      salt_join_token = '--%%*&-'
      sorcery_model_property_set(:salt_join_token, salt_join_token)

      expect(User.sorcery_config.salt_join_token).to eq salt_join_token
    end

    it "enables configuration option 'stretches'" do
      stretches = 15
      sorcery_model_property_set(:stretches, stretches)

      expect(User.sorcery_config.stretches).to eq stretches
    end

    it "enables configuration option 'deliver_later_enabled" do
      sorcery_model_property_set(:email_delivery_method, :deliver_later)
      expect(User.sorcery_config.email_delivery_method).to eq :deliver_later
    end

    it 'respond to username=' do
      expect(User.new).to respond_to(:username=)
    end
  end

  describe 'when activated with sorcery' do
    before(:all) { sorcery_reload! }
    before(:each) { User.sorcery_adapter.delete_all }

    it 'does not add authenticate method to base class', active_record: true do
      expect(ActiveRecord::Base).not_to respond_to(:authenticate) if defined?(ActiveRecord)
    end

    it 'responds to class method authenticate' do
      expect(User).to respond_to :authenticate
    end

    describe '#authenticate' do
      it 'returns user if credentials are good' do
        expect(User.authenticate(user.email, 'secret')).to eq user
      end

      it 'returns nil if credentials are bad' do
        expect(User.authenticate(user.email, 'wrong!')).to be nil
      end

      context 'downcasing username' do
        after do
          sorcery_reload!
        end

        context 'when downcasing set to false' do
          before do
            sorcery_model_property_set(:downcase_username_before_authenticating, false)
          end

          it 'does not find user with wrongly capitalized username' do
            expect(User.authenticate(user.email.capitalize, 'secret')).to be_nil
          end

          it 'finds user with correctly capitalized username' do
            expect(User.authenticate(user.email, 'secret')).to eq user
          end
        end

        context 'when downcasing set to true' do
          before do
            sorcery_model_property_set(:downcase_username_before_authenticating, true)
          end

          it 'does not find user with wrongly capitalized username' do
            expect(User.authenticate(user.email.capitalize, 'secret')).to eq user
          end

          it 'finds user with correctly capitalized username' do
            expect(User.authenticate(user.email, 'secret')).to eq user
          end
        end
      end

      context 'and model implements active_for_authentication?' do
        it 'authenticates returns user if active_for_authentication? returns true' do
          allow_any_instance_of(User).to receive(:active_for_authentication?) { true }

          expect(User.authenticate(user.email, 'secret')).to eq user
        end

        it 'authenticate returns nil if active_for_authentication? returns false' do
          allow_any_instance_of(User).to receive(:active_for_authentication?) { false }

          expect(User.authenticate(user.email, 'secret')).to be_nil
        end
      end

      context 'in block mode' do
        it 'yields the user if credentials are good' do
          User.authenticate(user.email, 'secret') do |user2, failure|
            expect(user2).to eq user
            expect(failure).to be_nil
          end
        end

        it 'yields the user and proper error if credentials are bad' do
          User.authenticate(user.email, 'wrong!') do |user2, failure|
            expect(user2).to eq user
            expect(failure).to eq :invalid_password
          end
        end

        it 'yields the proper error if no user exists' do
          [nil, '', 'not@a.user'].each do |email|
            User.authenticate(email, 'wrong!') do |user2, failure|
              expect(user2).to be_nil
              expect(failure).to eq :invalid_login
            end
          end
        end
      end
    end

    specify { expect(User).to respond_to(:encrypt) }

    it 'subclass inherits config if defined so' do
      sorcery_reload!([], subclasses_inherit_config: true)
      class Admin < User; end

      expect(Admin.sorcery_config).not_to be_nil
      expect(Admin.sorcery_config).to eq User.sorcery_config
    end

    it 'subclass does not inherit config if not defined so' do
      sorcery_reload!([], subclasses_inherit_config: false)
      class Admin2 < User; end

      expect(Admin2.sorcery_config).to be_nil
    end
  end

  describe 'registration' do
    before(:all) { sorcery_reload! }
    before(:each) { User.sorcery_adapter.delete_all }

    it 'by default, encryption_provider is not nil' do
      expect(User.sorcery_config.encryption_provider).not_to be_nil
    end

    it 'encrypts password when a new user is saved' do
      expect(
        User.sorcery_config.encryption_provider.matches?(crypted_password, 'secret', user.salt)
      ).to be true
    end

    it 'clears the virtual password field if the encryption process worked' do
      expect(user.password).to be_nil
    end

    it 'does not clear the virtual password field if save failed due to validity' do
      User.class_eval do
        validates_format_of :email, with: /\A(.)+@(.)+\Z/,
                                    if: proc { |r| r.email }, message: 'is invalid'
      end

      user.password = 'blupush'
      user.email = 'asd'
      user.save

      expect(user.password).not_to be_nil
    end

    it 'does not clear the virtual password field if save failed due to exception' do
      user.password = '4blupush'
      user.username = nil

      expect(user).to receive(:save) { raise RuntimeError }

      # rubocop:disable Lint/HandleExceptions
      begin
        user.save
      rescue RuntimeError
        # Intentionally force exception during save
      end
      # rubocop:enable Lint/HandleExceptions

      expect(user.password).not_to be_nil
    end

    it 'does not encrypt the password twice when a user is updated' do
      user.email = 'blup@bla.com'
      user.save

      expect(
        User.sorcery_config.encryption_provider.matches?(crypted_password, 'secret', user.salt)
      ).to be true
    end

    it 'replaces the crypted_password in case a new password is set' do
      user.password = 'new_secret'
      user.save

      expect(
        User.sorcery_config.encryption_provider.matches?(crypted_password, 'secret', user.salt)
      ).to be false
    end

    describe 'when user has password_confirmation_defined' do
      before(:all) do
        update_model { attr_accessor :password_confirmation }
      end

      after(:all) do
        User.send(:remove_method, :password_confirmation)
        User.send(:remove_method, :password_confirmation=)
      end

      it 'clears the virtual password field if the encryption process worked' do
        user = create_new_user(
          username: 'u',
          password: 'secret', password_confirmation: 'secret',
          email: 'email@example.com'
        )

        expect(user.password_confirmation).to be_nil
      end

      it 'does not clear the virtual password field if save failed due to validity' do
        User.class_eval do
          validates_format_of :email, with: /\A(.)+@(.)+\Z/
        end
        user = build_new_user(
          username: 'u',
          password: 'secret', password_confirmation: 'secret',
          email: 'asd'
        )
        user.save

        expect(user.password_confirmation).not_to be_nil
      end
    end
  end

  describe 'password validation' do
    let(:user_with_pass) do
      create_new_user(username: 'foo_bar', email: 'foo@bar.com', password: 'foobar')
    end

    specify { expect(user_with_pass).to respond_to :valid_password? }

    it 'returns true if password is correct' do
      expect(user_with_pass.valid_password?('foobar')).to be true
    end

    it 'returns false if password is incorrect' do
      expect(user_with_pass.valid_password?('foobug')).to be false
    end
  end

  describe 'generic send email' do
    before(:all) do
      MigrationHelper.migrate("#{Rails.root}/db/migrate/activation")
      User.reset_column_information
    end

    after(:all) do
      MigrationHelper.rollback("#{Rails.root}/db/migrate/activation")
    end

    before do
      @mail = double('mail')
      allow(::SorceryMailer).to receive(:activation_success_email).and_return(@mail)
    end

    it 'use deliver_later' do
      sorcery_reload!(
        %i[
          user_activation
          user_activation_mailer
          activation_needed_email_method_name
          email_delivery_method
        ],
        user_activation_mailer: SorceryMailer,
        activation_needed_email_method_name: nil,
        email_delivery_method: :deliver_later
      )

      expect(@mail).to receive(:deliver_later).once
      user.activate!
    end

    describe 'email_delivery_method is default' do
      it 'use deliver_now' do
        sorcery_reload!(
          %i[
            user_activation
            user_activation_mailer
            activation_needed_email_method_name
          ],
          user_activation_mailer: SorceryMailer,
          activation_needed_email_method_name: nil
        )

        expect(@mail).to receive(:deliver_now).once
        user.activate!
      end
    end
  end

  describe 'special encryption cases' do
    before(:all) do
      sorcery_reload!
      @text = 'Some Text!'
    end

    before(:each) do
      User.sorcery_adapter.delete_all
    end

    after(:each) do
      User.sorcery_config.reset!
    end

    it 'works with no password encryption' do
      sorcery_model_property_set(:encryption_algorithm, :none)
      username = user.send(User.sorcery_config.username_attribute_names.first)

      expect(User.authenticate(username, 'secret')).to be_truthy
    end

    it 'works with custom password encryption' do
      class MyCrypto
        def self.encrypt(*tokens)
          tokens.flatten.join('').tr('e', 'A')
        end

        def self.matches?(crypted, *tokens)
          crypted == encrypt(*tokens)
        end
      end
      sorcery_model_property_set(:encryption_algorithm, :custom)
      sorcery_model_property_set(:custom_encryption_provider, MyCrypto)

      username = user.send(User.sorcery_config.username_attribute_names.first)

      expect(User.authenticate(username, 'secret')).to be_truthy
    end

    it 'if encryption algo is aes256, it sets key to crypto provider' do
      sorcery_model_property_set(:encryption_algorithm, :aes256)
      sorcery_model_property_set(:encryption_key, nil)

      expect { User.encrypt @text }.to raise_error(ArgumentError)

      sorcery_model_property_set(:encryption_key, 'asd234dfs423fddsmndsflktsdf32343')

      expect { User.encrypt @text }.not_to raise_error
    end

    it 'if encryption algo is aes256, it sets key to crypto provider, even if attributes are set in reverse' do
      sorcery_model_property_set(:encryption_key, nil)
      sorcery_model_property_set(:encryption_algorithm, :none)
      sorcery_model_property_set(:encryption_key, 'asd234dfs423fddsmndsflktsdf32343')
      sorcery_model_property_set(:encryption_algorithm, :aes256)

      expect { User.encrypt @text }.not_to raise_error
    end

    it 'if encryption algo is md5 it works' do
      sorcery_model_property_set(:encryption_algorithm, :md5)

      expect(User.encrypt(@text)).to eq Sorcery::CryptoProviders::MD5.encrypt(@text)
    end

    it 'if encryption algo is sha1 it works' do
      sorcery_model_property_set(:encryption_algorithm, :sha1)

      expect(User.encrypt(@text)).to eq Sorcery::CryptoProviders::SHA1.encrypt(@text)
    end

    it 'if encryption algo is sha256 it works' do
      sorcery_model_property_set(:encryption_algorithm, :sha256)

      expect(User.encrypt(@text)).to eq Sorcery::CryptoProviders::SHA256.encrypt(@text)
    end

    it 'if encryption algo is sha512 it works' do
      sorcery_model_property_set(:encryption_algorithm, :sha512)

      expect(User.encrypt(@text)).to eq Sorcery::CryptoProviders::SHA512.encrypt(@text)
    end

    it 'if encryption algo is bcrypt it works' do
      sorcery_model_property_set(:encryption_algorithm, :bcrypt)

      # comparison is done using BCrypt::Password#==(raw_token), not by String#==
      expect(User.encrypt(@text)).to be_an_instance_of BCrypt::Password
      expect(User.encrypt(@text)).to eq @text
    end

    it 'salt is random for each user and saved in db' do
      sorcery_model_property_set(:salt_attribute_name, :salt)

      expect(user.salt).not_to be_nil
    end

    it 'if salt is set uses it to encrypt' do
      sorcery_model_property_set(:salt_attribute_name, :salt)
      sorcery_model_property_set(:encryption_algorithm, :sha512)

      expect(user.crypted_password).not_to eq Sorcery::CryptoProviders::SHA512.encrypt('secret')
      expect(user.crypted_password).to eq Sorcery::CryptoProviders::SHA512.encrypt('secret', user.salt)
    end

    it 'if salt_join_token is set uses it to encrypt' do
      sorcery_model_property_set(:salt_attribute_name, :salt)
      sorcery_model_property_set(:salt_join_token, '-@=>')
      sorcery_model_property_set(:encryption_algorithm, :sha512)

      expect(user.crypted_password).not_to eq Sorcery::CryptoProviders::SHA512.encrypt('secret')

      Sorcery::CryptoProviders::SHA512.join_token = ''

      expect(user.crypted_password).not_to eq Sorcery::CryptoProviders::SHA512.encrypt('secret', user.salt)

      Sorcery::CryptoProviders::SHA512.join_token = User.sorcery_config.salt_join_token

      expect(user.crypted_password).to eq Sorcery::CryptoProviders::SHA512.encrypt('secret', user.salt)
    end

    it 'if pepper is set uses it to encrypt' do
      sorcery_model_property_set(:salt_attribute_name, :salt)
      sorcery_model_property_set(:pepper, '++@^$')
      sorcery_model_property_set(:encryption_algorithm, :bcrypt)

      # password comparison is done using BCrypt::Password#==(raw_token), not String#==
      bcrypt_password = BCrypt::Password.new(user.crypted_password)
      allow(::BCrypt::Password).to receive(:create) do |token, options = {}|
        # need to use common BCrypt's salt when genarating BCrypt::Password objects
        # so that any generated password hashes can be compared each other
        ::BCrypt::Engine.hash_secret(token, bcrypt_password.salt)
      end

      expect(user.crypted_password).not_to eq Sorcery::CryptoProviders::BCrypt.encrypt('secret')

      Sorcery::CryptoProviders::BCrypt.pepper = ''

      expect(user.crypted_password).not_to eq Sorcery::CryptoProviders::BCrypt.encrypt('secret', user.salt)

      Sorcery::CryptoProviders::BCrypt.pepper = User.sorcery_config.pepper

      expect(user.crypted_password).to eq Sorcery::CryptoProviders::BCrypt.encrypt('secret', user.salt)
    end

    it 'if pepper is empty string (default) does not use pepper to encrypt' do
      sorcery_model_property_set(:salt_attribute_name, :salt)
      sorcery_model_property_set(:pepper, '')
      sorcery_model_property_set(:encryption_algorithm, :bcrypt)

      # password comparison is done using BCrypt::Password#==(raw_token), not String#==
      bcrypt_password = BCrypt::Password.new(user.crypted_password)
      allow(::BCrypt::Password).to receive(:create) do |token, options = {}|
        # need to use common BCrypt's salt when genarating BCrypt::Password objects
        # so that any generated password hashes can be compared each other
        ::BCrypt::Engine.hash_secret(token, bcrypt_password.salt)
      end

      expect(user.crypted_password).not_to eq Sorcery::CryptoProviders::BCrypt.encrypt('secret')

      Sorcery::CryptoProviders::BCrypt.pepper = 'some_pepper'

      expect(user.crypted_password).not_to eq Sorcery::CryptoProviders::BCrypt.encrypt('secret', user.salt)

      Sorcery::CryptoProviders::BCrypt.pepper = User.sorcery_config.pepper

      expect(user.crypted_password).to eq Sorcery::CryptoProviders::BCrypt.encrypt('secret', user.salt)
    end
  end

  describe 'ORM adapter' do
    before(:all) do
      sorcery_reload!
      User.sorcery_adapter.delete_all
    end

    before(:each) { user }

    after(:each) do
      User.sorcery_adapter.delete_all
      User.sorcery_config.reset!
    end

    it 'find_by_username works as expected' do
      sorcery_model_property_set(:username_attribute_names, [:username])

      expect(User.sorcery_adapter.find_by_username('gizmo')).to eq user
    end

    it 'find_by_username works as expected with multiple username attributes' do
      sorcery_model_property_set(:username_attribute_names, %i[username email])

      expect(User.sorcery_adapter.find_by_username('gizmo')).to eq user
    end

    it 'find_by_email works as expected' do
      expect(User.sorcery_adapter.find_by_email('bla@bla.com')).to eq user
    end
  end
end

shared_examples_for 'external_user' do
  let(:user) { create_new_user }
  let(:external_user) { create_new_external_user :twitter }

  before(:all) do
    if SORCERY_ORM == :active_record
      MigrationHelper.migrate("#{Rails.root}/db/migrate/external")
      MigrationHelper.migrate("#{Rails.root}/db/migrate/activation")
    end
    sorcery_reload!
  end

  after(:all) do
    if SORCERY_ORM == :active_record
      MigrationHelper.rollback("#{Rails.root}/db/migrate/external")
      MigrationHelper.rollback("#{Rails.root}/db/migrate/activation")
    end
  end

  before(:each) do
    User.sorcery_adapter.delete_all
  end

  it "responds to 'external?'" do
    expect(user).to respond_to(:external?)
  end

  it 'external? is false for regular users' do
    expect(user.external?).to be false
  end

  it 'external? is true for external users' do
    expect(external_user.external?).to be true
  end

  describe '.create_from_provider' do
    before(:each) do
      sorcery_reload!([:external])
      sorcery_model_property_set(:authentications_class, Authentication)
    end

    it 'supports nested attributes' do
      expect do
        User.create_from_provider('facebook', '123', username: 'Noam Ben Ari')
      end.to change { User.count }.by(1)

      expect(User.first.username).to eq 'Noam Ben Ari'
    end

    context 'with block' do
      it 'create user when block return true' do
        expect do
          User.create_from_provider('facebook', '123', username: 'Noam Ben Ari') { true }
        end.to change { User.count }.by(1)
      end

      it 'does not create user when block return false' do
        expect do
          User.create_from_provider('facebook', '123', username: 'Noam Ben Ari') { false }
        end.not_to(change { User.count })
      end
    end
  end

  describe 'activation' do
    before(:each) do
      sorcery_reload!(%i[user_activation external], user_activation_mailer: ::SorceryMailer)
    end

    after(:each) do
      User.sorcery_adapter.delete_all
    end

    %i[facebook github google liveid slack].each do |provider|
      it 'does not send activation email to external users' do
        old_size = ActionMailer::Base.deliveries.size
        create_new_external_user(provider)

        expect(ActionMailer::Base.deliveries.size).to eq old_size
      end

      it 'does not send external users an activation success email' do
        sorcery_model_property_set(:activation_success_email_method_name, nil)
        create_new_external_user(provider)
        old_size = ActionMailer::Base.deliveries.size
        @user.activate!

        expect(ActionMailer::Base.deliveries.size).to eq old_size
      end
    end
  end
end
