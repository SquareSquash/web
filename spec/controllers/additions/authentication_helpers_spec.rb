# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'spec_helper'

class FakeController
  def self.helper_method(*args) end
  def logger(*args) Rails.logger end
  def session() @session ||= Hash.new end

  def _current_user() @current_user end
  def _current_user=(u) @current_user = u end

  include AuthenticationHelpers
end

describe AuthenticationHelpers do
  before(:all) { @user = FactoryGirl.create(:user) }
  before(:each) { @controller = FakeController.new }

  describe "#log_out" do
    it "should clear the session and @current_user" do
      @controller.session[:user_id] = @user.id
      @controller._current_user     = @user

      @controller.log_out

      expect(@controller.session[:user_id]).to be_nil
      expect(@controller._current_user).to be_nil
    end
  end

  describe "#current_user" do
    it "should return the cached user" do
      @controller._current_user     = @user
      @controller.session[:user_id] = @user.id
      expect(@controller.current_user).to eql(@user)
    end

    it "should locate the user from the session" do
      @controller.session[:user_id] = @user.id
      expect(@controller.current_user).to eql(@user)
      expect(@controller._current_user).to eql(@user)
    end

    it "should return nil if the session is blank, even if there is a cached user" do
      @controller._current_user = @user
      expect(@controller.current_user).to be_nil
    end
  end

  describe "#logged_in?" do
    it "should return true if the user is logged in" do
      @controller.send :log_in_user,  @user
      expect(@controller.logged_in?).to be_true
    end

    it "should return false if the user is logged out" do
      @controller.log_out
      expect(@controller.logged_in?).to be_false
    end
  end

  describe "#logged_out?" do
    it "should return true if the user is logged out" do
      @controller.log_out
      expect(@controller.logged_out?).to be_true
    end

    it "should return false if the user is logged in" do
      @controller.send :log_in_user,  @user
      expect(@controller.logged_out?).to be_false
    end
  end

  describe "#login_required" do
    it "should return true if the user is logged in" do
      @controller.send :log_in_user,  @user
      expect(@controller.send(:login_required)).to be_true
    end

    it "should return false and redirect if the user is logged out" do
      expect(@controller).to receive(:respond_to).once
      @controller.log_out
      expect(@controller.send(:login_required)).to be_false
    end
  end

  describe "#must_be_unauthenticated" do
    it "should return false and redirect if the user is logged in" do
      expect(@controller).to receive(:respond_to).once
      @controller.send :log_in_user,  @user
      expect(@controller.send(:must_be_unauthenticated)).to be_false
    end

    it "should return true if the user is logged out" do
      @controller.log_out
      expect(@controller.send(:must_be_unauthenticated)).to be_true
    end
  end

  describe "#log_in_user" do
    it "should set the session and the cached user" do
      @controller.send :log_in_user,  @user
      expect(@controller.session[:user_id]).to eql(@user.id)
      expect(@controller._current_user).to eql(@user)
    end
  end
end
