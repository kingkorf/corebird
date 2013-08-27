/*  This file is part of corebird, a Gtk+ linux Twitter client.
 *  Copyright (C) 2013 Timm Bäder
 *
 *  corebird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  corebird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with corebird.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
[GtkTemplate (ui = "/org/baedert/corebird/ui/tweet-info-page.ui")]
class TweetInfoPage : IPage , ScrollWidget {
  public static const uint BY_INSTANCE = 1;
  public static const uint BY_ID       = 2;

  public int unread_count { get{return 0;} set {} }
  private int id;
  public unowned MainWindow main_window { get; set; }
  public unowned Account account { get; set; }
  private int64 tweet_id;
  private bool values_set = false;
  private Tweet tweet;

  [GtkChild]
  private Label text_label;
  [GtkChild]
  private Label author_label;
  [GtkChild]
  private Image avatar_image;
  [GtkChild]
  private Label retweets_label;
  [GtkChild]
  private Label favorites_label;
  [GtkChild]
  private ListBox bottom_list_box;
  [GtkChild]
  private Spinner progress_spinner;
  [GtkChild]
  private ToggleButton favorite_button;
  [GtkChild]
  private ToggleButton retweet_button;



  public TweetInfoPage (int id) {
    this.id = id;
    this.button_press_event.connect (button_pressed_event_cb);
  }

  public void on_join (int page_id, va_list args){
    uint mode = args.arg ();

    if (mode == 0)
      return;

    values_set = false;


    bottom_list_box.foreach ((w) => {bottom_list_box.remove (w);});
    bottom_list_box.hide ();
    progress_spinner.hide ();


    if (mode == BY_INSTANCE) {
      this.tweet = args.arg ();
      this.tweet_id = tweet.id;
      set_tweet_data (tweet);

    } else if (mode == BY_ID) {
      this.tweet_id = args.arg ();
    }

    query_tweet_info ();
  }


  [GtkCallback]
  private void favorite_button_toggled_cb () {
    if (!values_set)
      return;

    favorite_button.sensitive = false;
    TweetUtils.toggle_favorite_tweet.begin (account, tweet, favorite_button.active, () => {
        favorite_button.sensitive = true;
    });
  }

  [GtkCallback]
  private void retweet_button_toggled_cb () {
    if (!values_set)
      return;
    retweet_button.sensitive = false;
    TweetUtils.toggle_retweet_tweet.begin (account, tweet, !retweet_button.active, () => {
      retweet_button.sensitive = true;
    });
  }

  [GtkCallback]
  private void reply_button_clicked_cb () {
    message ("reply!");
  }

  /**
   * Loads the data of the tweet with the id tweet_id from the Twitter server.
   */
  private void query_tweet_info () {
    var call = account.proxy.new_call ();
    call.set_method ("GET");
    call.set_function ("1.1/statuses/show.json");
    call.add_param ("id", tweet_id.to_string ());
    call.invoke_async.begin (null, (obj, res) => {
      try{call.invoke_async.end (res);}catch(GLib.Error e){critical(e.message);return;}
      var now = new GLib.DateTime.now_local ();
      this.tweet = new Tweet ();
      var parser = new Json.Parser ();
      parser.load_from_data (call.get_payload ());
      tweet.load_from_json (parser.get_root (), now);
      set_tweet_data (tweet);
      Json.Object root_object = parser.get_root ().get_object ();
      if (!root_object.get_null_member ("place"))
        author_label.label += " in " + root_object.get_string_member ("place");

      if (tweet.reply_id != 0) {
        progress_spinner.show();
        progress_spinner.start ();
        load_replied_to_tweet (tweet.reply_id);
      }
      values_set = true;
    });

  }

  /**
   * Loads the tweet this tweet is a reply to.
   * This will recursively call itself until the end of the chain is reached.
   *
   * @param reply_id The id of the tweet the previous tweet was a reply to.
   */
  private void load_replied_to_tweet (int64 reply_id) {
    if (reply_id == 0) {
      progress_spinner.stop ();
      progress_spinner.hide ();
      return;
    }

    bottom_list_box.show ();
    var call = account.proxy.new_call ();
    call.set_function ("1.1/statuses/show.json");
    call.set_method ("GET");
    call.add_param ("id", reply_id.to_string ());
    call.invoke_async.begin (null, (obj, res) => {
      try{call.invoke_async.end (res);}catch(GLib.Error e){critical(e.message);return;}
      var parser = new Json.Parser ();
      parser.load_from_data (call.get_payload ());
      Tweet tweet = new Tweet ();
      tweet.load_from_json (parser.get_root (), new GLib.DateTime.now_local ());
      bottom_list_box.add (new TweetListEntry (tweet, main_window, account));
      load_replied_to_tweet (tweet.reply_id);
    });
  }

  /**
   *
   */
  private void set_tweet_data (Tweet tweet) {
    GLib.DateTime created_at = new GLib.DateTime.from_unix_local (tweet.created_at);
    string time_format = created_at.format ("%x, %X");

    text_label.label = "<b><i><big><big><big>»"+tweet.get_formatted_text ()+"«</big></big></big></i></b>";
    author_label.label = "- %s at %s".printf (tweet.user_name, time_format);
    avatar_image.pixbuf = tweet.avatar;
    retweets_label.label = _("Retweets: ") + tweet.retweet_count.to_string ();
    favorites_label.label = _("Favorites: ") + tweet.favorite_count.to_string ();
    retweet_button.active = tweet.retweeted;
    favorite_button.active = tweet.favorited;
  }

  public int get_id () {
    return id;
  }
  public void create_tool_button (Gtk.RadioToolButton? group) {}
  public Gtk.RadioToolButton? get_tool_button () {
    return null;
  }
}