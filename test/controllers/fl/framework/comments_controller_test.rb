require 'test_helper'

module Fl::Framework::Test
  class CommentsControllerTest < ControllerTestCase
    include Fl::Framework::Engine.routes.url_helpers

    setup do
      @routes = Fl::Framework::Engine.routes
#      @comment = fl_framework_comments(:one)
    end

    test 'index' do
      print("++++++++++ #{@routes.url_helpers.methods.sort}\n")
      print("++++++++++ #{comment_url}\n")
    end

    test "should get index" do
      get comments_url
      assert_response :success
    end

    test "should get new" do
      get new_comment_url
      assert_response :success
    end

    test "should create comment" do
      assert_difference('Comment.count') do
        post comments_url, params: { comment: { commentable: @comment.commentable, contents: @comment.contents, author: @comment.author, title: @comment.title } }
      end

      assert_redirected_to comment_url(Comment.last)
    end

    test "should show comment" do
      get comment_url(@comment)
      assert_response :success
    end

    test "should get edit" do
      get edit_comment_url(@comment)
      assert_response :success
    end

    test "should update comment" do
      patch comment_url(@comment), params: { comment: { commentable: @comment.commentable, contents: @comment.contents, author: @comment.author, title: @comment.title } }
      assert_redirected_to comment_url(@comment)
    end

    test "should destroy comment" do
      assert_difference('Comment.count', -1) do
        delete comment_url(@comment)
      end

      assert_redirected_to comments_url
    end
  end
end
