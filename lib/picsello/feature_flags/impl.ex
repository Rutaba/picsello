defimpl FunWithFlags.Actor, for: Picsello.Accounts.User do
  def id(%{email: email}) do
    "user:#{email}"
  end
end
