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

// TODO: Add timeout that removes all entries after X seconds when switched away
[GtkTemplate (ui = "/org/baedert/corebird/ui/search-page.ui")]
class SearchPage : IPage, Box {
  private static const int USER_COUNT = 3;
  /** The unread count here is always zero */
  public int unread_count {
    get { return 0; }
    set {;}
  }
  public unowned Account account        { get; set; }
  public unowned MainWindow main_window { set; get; }
  public int id                         { get; set; }
  [GtkChild]
  private SearchEntry search_entry;
  [GtkChild]
  private Button search_button;
  [GtkChild]
  private ListBox tweet_list; // TODO: Rename tweet_list
  [GtkChild]
  private Label users_header;
  [GtkChild]
  private Label tweets_header;
  [GtkChild]
  private Spinner placeholder;
  [GtkChild]
  private ScrollWidget scroll_widget;
  private RadioToolButton tool_button;
  public DeltaUpdater delta_updater;
  private LoadMoreEntry load_more_entry = new LoadMoreEntry ();
  private string search_query;
  private int user_page = 1;
  private int64 lowest_tweet_id = int64.MAX-1;
  private bool loading_tweets = false;


  public SearchPage (int id) {
    this.id = id;

    tweet_list.set_header_func (header_func);
    tweet_list.set_sort_func (ITwitterItem.sort_func);
    tweet_list.row_activated.connect (row_activated_cb);
    search_button.clicked.connect (() => {
      search_for (search_entry.get_text());
    });
    load_more_entry.get_button ().clicked.connect (() => {
      user_page++;
      load_users ();
    });
    scroll_widget.scrolled_to_end.connect (() => {
      load_tweets ();
    });
  }

  [GtkCallback]
  private void search_entry_activate_cb () {
    search_for (search_entry.get_text ());
  }

  /**
   * see IPage#onJoin
   */
  public void on_join (int page_id, va_list arg_list) {
    string? term = arg_list.arg<string>();
    if (term == null) {
      warning ("No search term provided");
      return;
    }

    search_for (term, true);
  }

  public void on_leave () {}

  public void search_for (string search_term, bool set_text = false) { //{{{
    if(search_term.length == 0)
      return;

    string q = search_term;

    // clear the list
    clear_list ();
    placeholder.show ();
    placeholder.start ();
    tweet_list.set_placeholder (placeholder);


    if (set_text)
      search_entry.set_text(search_term);

    if (!Settings.get_bool ("search-show-retweets"))
      q += " -rt";

    this.search_query    = GLib.Uri.escape_string (q);
    this.user_page       = 1;
    this.lowest_tweet_id = int64.MAX-1;

    load_tweets ();
    load_users ();
  } //}}}

  private void row_activated_cb (ListBoxRow row) { // {{{
    if (row is UserListEntry) {
      main_window.switch_page (MainWindow.PAGE_PROFILE,
                               ((UserListEntry)row).user_id);
    } else if (row is TweetListEntry) {
      main_window.switch_page (MainWindow.PAGE_TWEET_INFO,
                               TweetInfoPage.BY_INSTANCE,
                               ((TweetListEntry)row).tweet);
    }
  } //}}}

  private void header_func (ListBoxRow row, ListBoxRow? before) { //{{{
    Widget header = row.get_header ();
    if (header != null)
      return;

    if (before == null && row is UserListEntry) {
      row.set_header (users_header);
    } else if ((before is UserListEntry || before is LoadMoreEntry) && row is TweetListEntry) {
      row.set_header (tweets_header);
    }
  } //}}}

  private void load_users () {  // {{{
    var user_call = account.proxy.new_call ();
    user_call.set_method ("GET");
    user_call.set_function ("1.1/users/search.json");
    user_call.add_param ("q", this.search_query);
    user_call.add_param ("count", USER_COUNT.to_string ());
    user_call.add_param ("include_entities", "false");
    user_call.add_param ("page", user_page.to_string ());
    user_call.invoke_async.begin (null, (obj, res) => {
      try {
        user_call.invoke_async.end (res);
      } catch (GLib.Error e) {
        warning (e.message);
        return;
      }

      var parser = new Json.Parser ();
      try {
        parser.load_from_data (user_call.get_payload ());
      } catch (GLib.Error e) {
        warning (e.message);
        return;
      }

      var users = parser.get_root ().get_array ();
      users.foreach_element ((array, index, node) => {
        var user_obj = node.get_object ();
        var entry = new UserListEntry ();
        entry.screen_name = "@" + user_obj.get_string_member ("screen_name");
        entry.name = user_obj.get_string_member ("name");
        entry.avatar = user_obj.get_string_member ("profile_image_url");
        entry.user_id = user_obj.get_int_member ("id");
        tweet_list.add (entry);
      });
      if (users.get_length () >= USER_COUNT) {
        if (load_more_entry.parent == null)
          tweet_list.add (load_more_entry);
      } else {
        load_more_entry.hide ();
      }
    });

  } // }}}

  private void load_tweets () { // {{{
    if (loading_tweets)
      return;

    loading_tweets = true;
    main_window.start_progress ();
    var call = account.proxy.new_call ();
    call.set_function ("1.1/search/tweets.json");
    call.set_method ("GET");
    call.add_param ("q", this.search_query);
    call.add_param ("max_id", (lowest_tweet_id - 1).to_string ());
    call.add_param ("count", "35");
    call.invoke_async.begin (null, (obj, res) => {
      try{
        call.invoke_async.end (res);
      } catch (GLib.Error e) {
        warning (e.message);
        return;
      }
      string back = call.get_payload ();
      Json.Parser parser = new Json.Parser ();
      try {
        parser.load_from_data (back);
      } catch (GLib.Error e) {
        critical(" %s\nDATA:\n%s", e.message, back);
      }
      var now = new GLib.DateTime.now_local ();
      var statuses = parser.get_root().get_object().get_array_member("statuses");
      statuses.foreach_element ((array, index, node) => {
        var tweet = new Tweet ();
        tweet.load_from_json (node, now);
        if (tweet.id < lowest_tweet_id)
          lowest_tweet_id = tweet.id;
        var entry = new TweetListEntry (tweet, main_window, account);
        delta_updater.add (entry);
        tweet_list.add (entry);
      });
      loading_tweets = false;
      main_window.stop_progress ();
    });

  } // }}}

  /**
   * Deletes all rows from the list of search results
   */
  private void clear_list () {
    tweet_list.foreach ((w) => {
      tweet_list.remove (w);
    });
  }

  public void create_tool_button(RadioToolButton? group){
    tool_button = new RadioToolButton.from_widget (group);
    tool_button.icon_name = "corebird-search-symbolic";
    tool_button.label = "Search";
  }

  public RadioToolButton? get_tool_button(){
    return tool_button;
  }
}

[GtkTemplate (ui = "/org/baedert/corebird/ui/load-more-entry.ui")]
class LoadMoreEntry : Gtk.ListBoxRow, ITwitterItem {
  public int64 sort_factor {
    get { return int64.MAX-2; }
  }
  public bool seen {
    get { return true; }
    set {}
  }
  [GtkChild]
  private Button load_more_button;

  public LoadMoreEntry () {}
  public Button get_button () {
    return load_more_button;
  }
  public int update_time_delta (GLib.DateTime? now = null) {return 0;}
}
