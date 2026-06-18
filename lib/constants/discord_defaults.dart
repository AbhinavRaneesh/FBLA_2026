/// Default Discord chapter config for the in-app Discord Hub.
/// Used when Firestore `discord_config/default` is missing or incomplete.
class DiscordDefaults {
  DiscordDefaults._();

  static const String inviteUrl = 'https://discord.gg/bErBych9r0';
  static const String guildName = 'FBLA Chapter Server';
  static const bool botEnabled = true;
}
