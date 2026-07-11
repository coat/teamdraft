# frozen_string_literal: true

class Admin::UsersController < Admin::BaseController
  before_action :load_user, only: [:show, :edit, :update, :grant_admin, :revoke_admin, :disable, :enable]

  def index
    query = Admin::Users::ListQuery.new(params)
    pagy, users = pagy(query.relation)
    render Views::Admin::Users::Index.new(query: query, users: users, pagy: pagy)
  end

  def show
    participants = @user.participants.includes(league_season: :league).to_a
    render Views::Admin::Users::Show.new(user: @user, participants: participants)
  end

  def edit
    render Views::Admin::Users::Edit.new(user: @user)
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "Updated #{@user.email_address}."
    else
      render Views::Admin::Users::Edit.new(user: @user), status: :unprocessable_content
    end
  end

  def grant_admin
    @user.update!(admin: true)
    redirect_to admin_user_path(@user), notice: "#{@user.email_address} is now an admin."
  end

  def revoke_admin
    if @user == current_user
      return redirect_to admin_user_path(@user), alert: "You can't revoke your own admin access."
    end
    unless User.where(admin: true).where.not(id: @user.id).exists?
      return redirect_to admin_user_path(@user), alert: "Can't revoke the last admin."
    end
    @user.update!(admin: false)
    redirect_to admin_user_path(@user), notice: "#{@user.email_address} is no longer an admin."
  end

  def disable
    if @user == current_user
      return redirect_to admin_user_path(@user), alert: "You can't disable your own account."
    end
    User.transaction do
      @user.update!(disabled_at: Time.current)
      @user.sessions.destroy_all
    end
    redirect_to admin_user_path(@user), notice: "Disabled #{@user.email_address}."
  end

  def enable
    @user.update!(disabled_at: nil)
    redirect_to admin_user_path(@user), notice: "Enabled #{@user.email_address}."
  end

  private

  def load_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email_address)
  end
end
