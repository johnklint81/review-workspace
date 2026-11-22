# Before loading actual screening data

- [ ] Create three individual accounts with Supabase Auth (no shared password).
- [ ] Create a single project and three `project_members` rows via admin SQL.
- [ ] Verify all seven tables have RLS enabled.
- [ ] Verify signed-out visitors cannot query any project data.
- [ ] Verify a fourth authenticated nonmember cannot query project data.
- [ ] Verify a reviewer cannot write a decision for another reviewer or an unassigned article.
- [ ] Verify original decisions cannot be updated/deleted using client credentials.
- [ ] Verify conflict resolution rejects agreement cases and requires the third author for arbitration.
- [ ] Verify article assignments never exceed two reviewers and your import procedure assigns exactly two.
- [ ] Test simultaneous inserts/duplicate imports; adjust import code to use transactions/unique keys.
- [ ] Decide how corrections to erroneous imported screening decisions will be audited before importing real data.
- [ ] Configure backup/recovery and document retention expectations.
- [ ] Do not expose service-role keys, database credentials, or private author data in the Flutter bundle/GitHub.

Because RLS rules are security-sensitive, run integration tests with actual authenticated sessions and an independent nonmember account before production use.
