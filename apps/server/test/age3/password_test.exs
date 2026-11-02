defmodule Age3.PasswordTest do
  use ExUnit.Case, async: true

  alias Age3.Password

  test "a hash verifies its own password and nothing else" do
    hash = Password.hash("correct horse")
    assert "pbkdf2-sha256$" <> _ = hash
    assert Password.verify("correct horse", hash)
    refute Password.verify("correct hors", hash)
    refute Password.verify("", hash)
  end

  test "the same password hashes differently each time (random salt)" do
    refute Password.hash("same") == Password.hash("same")
  end

  test "broken hashes never verify" do
    broken = ["", "nope", "md5$1$AA$AA", "pbkdf2-sha256$0$AA$AA", "pbkdf2-sha256$x$AA$AA"]

    for bad <- ["pbkdf2-sha256$10$AA$" | broken] do
      refute Password.verify("pw", bad), bad
    end
  end

  test "no_user_verify is always false" do
    refute Password.no_user_verify()
  end

  test "generated passwords are 12 easy-to-read characters" do
    pw = Password.generate()
    assert pw =~ ~r/^[a-km-np-zA-HJ-NP-Z2-9]{12}$/
    refute pw == Password.generate()
  end
end
