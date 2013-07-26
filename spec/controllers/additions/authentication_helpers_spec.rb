# Copyright 2013 Square Inc.
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

      @controller.session[:user_id].should be_nil
      @controller._current_user.should be_nil
    end
  end

  describe "#current_user" do
    it "should return the cached user" do
      @controller._current_user     = @user
      @controller.session[:user_id] = @user.id
      @controller.current_user.should eql(@user)
    end

    it "should locate the user from the session" do
      @controller.session[:user_id] = @user.id
      @controller.current_user.should eql(@user)
      @controller._current_user.should eql(@user)
    end

    it "should return nil if the session is blank, even if there is a cached user" do
      @controller._current_user = @user
      @controller.current_user.should be_nil
    end
  end

  describe "#logged_in?" do
    it "should return true if the user is logged in" do
      @controller.send :log_in_user,  @user
      @controller.logged_in?.should be_true
    end

    it "should return false if the user is logged out" do
      @controller.log_out
      @controller.logged_in?.should be_false
    end
  end

  describe "#logged_out?" do
    it "should return true if the user is logged out" do
      @controller.log_out
      @controller.logged_out?.should be_true
    end

    it "should return false if the user is logged in" do
      @controller.send :log_in_user,  @user
      @controller.logged_out?.should be_false
    end
  end

  describe "#login_required" do
    it "should return true if the user is logged in" do
      @controller.send :log_in_user,  @user
      @controller.send(:login_required).should be_true
    end

    it "should return false and redirect if the user is logged out" do
      @controller.should_receive(:respond_to).once
      @controller.log_out
      @controller.send(:login_required).should be_false
    end
  end

  describe "#must_be_unauthenticated" do
    it "should return false and redirect if the user is logged in" do
      @controller.should_receive(:respond_to).once
      @controller.send :log_in_user,  @user
      @controller.send(:must_be_unauthenticated).should be_false
    end

    it "should return true if the user is logged out" do
      @controller.log_out
      @controller.send(:must_be_unauthenticated).should be_true
    end
  end

  describe "#log_in_user" do
    it "should set the session and the cached user" do
      @controller.send :log_in_user,  @user
      @controller.session[:user_id].should eql(@user.id)
      @controller._current_user.should eql(@user)
    end
  end
end
