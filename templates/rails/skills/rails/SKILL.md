---
name: Rails Expert
description: Deep expertise in Ruby on Rails - ActiveRecord, patterns, performance, security, testing
---

# Rails Expert Skill

This skill provides deep Rails expertise including ActiveRecord optimization, architectural patterns, security best practices, Hotwire integration, and testing strategies.

---

## 🔥 Common Pitfalls

### N+1 Query Problem

```ruby
# ❌ N+1 — 1 + N queries
Post.all.each do |post|
  puts post.author.name
end

# ✅ Eager loading — 2 queries
Post.includes(:author).each do |post|
  puts post.author.name
end

# ✅ Nested eager loading
Post.includes(author: :profile, comments: :user).all

# ✅ Preload vs Includes vs Eager_load
Post.preload(:author)     # Separate query
Post.includes(:author)    # Smart (preload or eager_load)
Post.eager_load(:author)  # LEFT OUTER JOIN
```

### Mass Assignment

```ruby
# ❌ Dangerous - permits everything
params.permit!

# ❌ Sensitive fields
params.require(:user).permit(:name, :email, :admin)

# ✅ Safe - explicit whitelist
params.require(:user).permit(:name, :email, :bio)

# ✅ Admin fields with explicit check
if current_user.admin?
  params.require(:user).permit(:name, :email, :admin)
else
  params.require(:user).permit(:name, :email)
end
```

### Callbacks Gotchas

```ruby
# ❌ Side effects in callbacks
class User < ApplicationRecord
  after_create :send_welcome_email  # Hard to test, implicit
end

# ✅ Explicit in controller/service
class UsersController < ApplicationController
  def create
    @user = User.create!(user_params)
    UserMailer.welcome(@user).deliver_later
  end
end

# When callbacks ARE appropriate:
# - Data normalization (before_validation)
# - Timestamps
# - Counter cache updates
```

---

## 🏗️ Architecture Patterns

### Service Objects (POROs)

```ruby
# app/services/users/create_user.rb
module Users
  class CreateUser
    def initialize(params, current_user: nil)
      @params = params
      @current_user = current_user
    end

    def call
      user = User.new(@params)

      ActiveRecord::Base.transaction do
        user.save!
        create_profile(user)
        enqueue_welcome_email(user)
      end

      Result.new(success: true, user: user)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, errors: e.record.errors)
    end

    private

    def create_profile(user)
      Profile.create!(user: user)
    end

    def enqueue_welcome_email(user)
      UserMailer.welcome(user).deliver_later
    end
  end
end

# Usage
result = Users::CreateUser.new(user_params).call
if result.success?
  redirect_to result.user
else
  render :new, status: :unprocessable_entity
end
```

### Query Objects

```ruby
# app/queries/active_users_query.rb
class ActiveUsersQuery
  def initialize(relation = User.all)
    @relation = relation
  end

  def call
    @relation
      .where(status: :active)
      .where("last_login_at > ?", 30.days.ago)
      .order(last_login_at: :desc)
  end

  def with_posts
    call.joins(:posts).distinct
  end
end

# Usage
ActiveUsersQuery.new.call
ActiveUsersQuery.new(User.premium).with_posts
```

### Form Objects

```ruby
# app/forms/registration_form.rb
class RegistrationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :password, :string
  attribute :terms_accepted, :boolean

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }
  validates :terms_accepted, acceptance: true

  def save
    return false unless valid?

    User.create!(email: email, password: password)
  end
end
```

---

## 🚀 Performance

### Database Indexing

```ruby
# Migration
class AddIndexesToPosts < ActiveRecord::Migration[7.1]
  def change
    add_index :posts, :user_id
    add_index :posts, :status
    add_index :posts, [:user_id, :status]
    add_index :posts, :created_at
    add_index :posts, :slug, unique: true
  end
end
```

### Query Optimization

```ruby
# Select only needed columns
User.select(:id, :name, :email).all

# Use exists? instead of count
User.where(email: email).exists?  # Better
User.where(email: email).count > 0  # Worse

# Pluck for simple values
User.where(active: true).pluck(:email)  # Returns array of emails

# find_each for large datasets
User.find_each(batch_size: 1000) do |user|
  user.process_something
end

# Avoid loading all records
User.active.limit(100)  # Not User.active.all
```

### Caching

```ruby
# Fragment caching
<% cache @post do %>
  <%= render @post %>
<% end %>

# Russian doll caching
<% cache @post do %>
  <% @post.comments.each do |comment| %>
    <% cache comment do %>
      <%= render comment %>
    <% end %>
  <% end %>
<% end %>

# Low-level caching
Rails.cache.fetch("user_#{user.id}_stats", expires_in: 1.hour) do
  user.calculate_stats
end

# Counter cache
belongs_to :user, counter_cache: true
# Requires: add_column :users, :posts_count, :integer, default: 0
```

---

## ⚡ Hotwire Patterns

### Turbo Frames

```erb
<%# app/views/posts/index.html.erb %>
<%= turbo_frame_tag "posts" do %>
  <%= render @posts %>
<% end %>

<%# app/views/posts/_post.html.erb %>
<%= turbo_frame_tag dom_id(post) do %>
  <article>
    <h2><%= post.title %></h2>
    <%= link_to "Edit", edit_post_path(post) %>
  </article>
<% end %>
```

### Turbo Streams

```ruby
# app/controllers/posts_controller.rb
def create
  @post = Post.new(post_params)

  respond_to do |format|
    if @post.save
      format.turbo_stream
      format.html { redirect_to @post }
    else
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

```erb
<%# app/views/posts/create.turbo_stream.erb %>
<%= turbo_stream.prepend "posts", @post %>
<%= turbo_stream.update "flash", partial: "shared/flash" %>
```

### Stimulus Controllers

```javascript
// app/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.performSearch()
    }, 300)
  }

  async performSearch() {
    const query = this.inputTarget.value
    const response = await fetch(`${this.urlValue}?q=${query}`)
    this.resultsTarget.innerHTML = await response.text()
  }
}
```

```erb
<div data-controller="search" data-search-url-value="<%= search_path %>">
  <input data-search-target="input" data-action="input->search#search">
  <div data-search-target="results"></div>
</div>
```

---

## 🔐 Security

### Strong Parameters

```ruby
class PostsController < ApplicationController
  private

  def post_params
    params.require(:post).permit(
      :title,
      :body,
      :published,
      tags: [],
      metadata: [:key, :value]
    )
  end
end
```

### Authorization (Pundit)

```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def show?
    record.published? || record.user == user
  end

  def update?
    record.user == user || user.admin?
  end

  def destroy?
    record.user == user || user.admin?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user).or(scope.published)
      end
    end
  end
end

# Controller
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])
    authorize @post
  end

  def index
    @posts = policy_scope(Post)
  end
end
```

### Rate Limiting (Rails 7.2+)

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  throttle("req/ip", limit: 100, period: 1.minute) do |req|
    req.ip
  end

  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/login" && req.post?
      req.ip
    end
  end
end
```

---

## 🧪 Testing

### RSpec Setup

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end

  describe "associations" do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
    it { is_expected.to belong_to(:organization).optional }
  end

  describe "#full_name" do
    let(:user) { build(:user, first_name: "John", last_name: "Doe") }

    it "returns the full name" do
      expect(user.full_name).to eq("John Doe")
    end
  end
end
```

### FactoryBot

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }

    trait :admin do
      admin { true }
    end

    trait :with_posts do
      transient do
        posts_count { 3 }
      end

      after(:create) do |user, evaluator|
        create_list(:post, evaluator.posts_count, user: user)
      end
    end
  end
end

# Usage
create(:user)
create(:user, :admin)
create(:user, :with_posts, posts_count: 5)
```

### Request Specs

```ruby
# spec/requests/posts_spec.rb
RSpec.describe "Posts", type: :request do
  let(:user) { create(:user) }

  describe "GET /posts" do
    it "returns success" do
      get posts_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /posts" do
    context "when authenticated" do
      before { sign_in user }

      it "creates a post" do
        expect {
          post posts_path, params: { post: { title: "Test", body: "Content" } }
        }.to change(Post, :count).by(1)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        post posts_path, params: { post: { title: "Test" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
```

### System Specs (Capybara)

```ruby
# spec/system/posts_spec.rb
RSpec.describe "Managing posts", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by(:rack_test)
    sign_in user
  end

  it "creates a new post" do
    visit new_post_path

    fill_in "Title", with: "My Post"
    fill_in "Body", with: "Post content"
    click_button "Create Post"

    expect(page).to have_content("Post was successfully created")
    expect(page).to have_content("My Post")
  end
end
```

---

## 📦 Useful Gems

| Gem | Purpose |
|-----|---------|
| `devise` | Authentication |
| `pundit` | Authorization |
| `sidekiq` | Background jobs |
| `pagy` | Pagination |
| `ransack` | Search/filtering |
| `friendly_id` | Slugs |
| `paper_trail` | Audit trail |
| `bullet` | N+1 detection |
| `annotate` | Model annotations |
| `rubocop-rails` | Rails linting |
