defmodule PolicrMini.Automation.LotteryCampaignTest do
  use ExUnit.Case, async: true

  alias PolicrMini.Automation.{Lottery, LotteryCampaign, LotteryDrawSnapshot, LotteryEntry, LotteryReferral}

  test "keeps the lottery audit proof fields in the production schema" do
    fields = LotteryCampaign.__schema__(:fields)

    assert :draw_seed in fields
    assert :entries_digest in fields
    assert :snapshot_count in fields
    assert :draw_algorithm in fields
    assert :enable_referrals in fields
    assert :auto_delete_entry_messages in fields
    assert :entry_message_delete_after_seconds in fields
    assert :weight in LotteryEntry.__schema__(:fields)
    assert :weight in LotteryDrawSnapshot.__schema__(:fields)
    assert :status in LotteryReferral.__schema__(:fields)
  end

  test "only enables configured deletion for keyword entry messages" do
    assert 12 =
             Lottery.entry_message_delete_delay(%LotteryCampaign{
               auto_delete_entry_messages: true,
               entry_message_delete_after_seconds: 12
             })

    assert Lottery.entry_message_delete_delay(%LotteryCampaign{
             auto_delete_entry_messages: false,
             entry_message_delete_after_seconds: 12
           }) == nil
  end

  test "matches administrator-defined lottery keywords exactly after trimming" do
    assert Lottery.keyword_matches?("参与", " 参与 ")
    assert Lottery.keyword_matches?("https://fk.wufeng.de/", "https://fk.wufeng.de/")
    assert Lottery.keyword_matches?("é", "é")

    refute Lottery.keyword_matches?("参与", "我要参与")
    refute Lottery.keyword_matches?("https://fk.wufeng.de/", "https://fk.wufeng.de")
  end

  test "selects a unique active campaign for a directly sent keyword" do
    campaigns = [
      %{id: 1, entry_keyword: "123参与"},
      %{id: 2, entry_keyword: "另一个关键词"}
    ]

    assert [%{id: 1}] = Lottery.matching_keyword_campaigns(campaigns, " 123参与 ")
    assert [] = Lottery.matching_keyword_campaigns(campaigns, "没有匹配")
  end

  test "keeps duplicate direct keywords ambiguous" do
    campaigns = [
      %{id: 1, entry_keyword: "参与"},
      %{id: 2, entry_keyword: "参与"}
    ]

    assert [%{id: 1}, %{id: 2}] = Lottery.matching_keyword_campaigns(campaigns, "参与")
  end
end
