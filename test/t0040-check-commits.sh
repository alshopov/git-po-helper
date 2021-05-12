#!/bin/sh

test_description="test git-po-helper check-commits"

. ./lib/sharness.sh

test_expect_success "setup" '
	git clone "$PO_HELPER_TEST_REPOSITORY" workdir &&
	test -f workdir/po/git.pot
'

test_expect_success "new commit with changes outside of po/" '
	(
		cd workdir &&
		echo A >po/A.txt &&
		echo B >po/B.txt &&
		echo C >C.txt &&
		git add -A &&
		cat >.git/commit-message <<-\EOF &&
		l10n: test: commit with changes outside of po/

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: found changes beyond \"po/\" directory"
		level=error msg="        C.txt"
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "new commit with unsupported hidden meta fields" '
	(
		cd workdir &&
		echo AA >po/A.txt &&
		echo BB >po/B.txt &&
		git add -u &&
		cat >.git/commit-message <<-\EOF &&
		l10n: test: commit with hidden meta fields

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit -F .git/commit-message &&
		git cat-file commit HEAD >.git/commit-meta &&
		sed -e "/^parent /a note: i am a hacker" \
			-e "/^committer /a note: happy coding" <.git/commit-meta \
			>.git/commit-hacked-meta &&

		cid=$(git hash-object -w -t commit .git/commit-hacked-meta) &&
		git update-ref refs/heads/master $cid &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: unknown commit header: note: i am a hacker"
		level=error msg="commit <OID>: unknown commit header: note: happy coding"
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "new commit with datetime in the future" '
	(
		cd workdir &&
		echo AAA >po/A.txt &&
		echo BBB >po/B.txt &&
		git add -u &&
		cat >.git/commit-message <<-\EOF &&
		l10n: test: commit with datetime in the future

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit -F .git/commit-message &&
		git cat-file commit HEAD >.git/commit-meta &&
		future=$(($(date -u +"%s")+100)) &&
		sed -e "s/^author .*/author Jiang Xin <worldhello.net@gmail.com> $future +0000/" \
			-e "s/^committer .*/committer Jiang Xin <worldhello.net@gmail.com> $future +0000/" \
			<.git/commit-meta >.git/commit-hacked-meta &&

		cid=$(git hash-object -w -t commit .git/commit-hacked-meta) &&
		git update-ref refs/heads/master $cid &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: bad author date: date is in the future, XX seconds from now"
		level=error msg="commit <OID>: bad committer date: date is in the future, XX seconds from now"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out |
			sed -e "s/[0-9]* seconds/XX seconds/g" >actual &&
		test_cmp expect actual
	)
'

test_expect_success "new commit with bad email address" '
	(
		cd workdir &&
		echo AAAA >po/A.txt &&
		echo BBBB >po/B.txt &&
		git add -u &&
		cat >.git/commit-message <<-\EOF &&
		l10n: test: commit with bad email address

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit -F .git/commit-message &&
		git cat-file commit HEAD >.git/commit-meta &&
		sed -e "s/^author .*/author Jiang Xin <worldhello.net AT gmail.com> 1112911993 +0800/" \
			-e "s/^committer .*/committer <worldhello.net@gmail.com> 1112911993 +0800/" \
			<.git/commit-meta >.git/commit-hacked-meta &&

		cid=$(git hash-object -w -t commit .git/commit-hacked-meta) &&
		git update-ref refs/heads/master $cid &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: bad format for author field: Jiang Xin <worldhello.net AT gmail.com> 1112911993 +0800"
		level=error msg="commit <OID>: bad format for committer field: <worldhello.net@gmail.com> 1112911993 +0800"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "too many commits to check" '
	(
		cd workdir &&
		test_must_fail env MAX_COMMITS=1 git-po-helper check-commits >actual 2>&1 &&
		cat >expect <<-\EOF &&
		level=error msg="too many commits to check (4 > 1), check args or use option --force"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_cmp expect actual
	)
'

test_expect_success "too many commits to check" '
	(
		cd workdir &&
		test_must_fail env MAX_COMMITS=1 git-po-helper check-commits --force >out 2>&1 &&
		make_user_friendly_and_stable_output <out |
			sed -e "s/[0-9]* seconds/XX seconds/g" >actual &&
		cat >expect <<-\EOF &&
		level=error msg="commit <OID>: bad format for author field: Jiang Xin <worldhello.net AT gmail.com> 1112911993 +0800"
		level=error msg="commit <OID>: bad format for committer field: <worldhello.net@gmail.com> 1112911993 +0800"
		level=error msg="commit <OID>: bad author date: date is in the future, XX seconds from now"
		level=error msg="commit <OID>: bad committer date: date is in the future, XX seconds from now"
		level=error msg="commit <OID>: unknown commit header: note: i am a hacker"
		level=error msg="commit <OID>: unknown commit header: note: happy coding"
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"
		level=error msg="commit <OID>: found changes beyond \"po/\" directory"
		level=error msg="        C.txt"
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_cmp expect actual
	)
'

test_expect_success "long subject, exceed hard limit" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		l10n: this subject has too many chracters, which is greater than threshold

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"
		level=error msg="commit <OID>: subject is too long (74 > 62)"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "long subject, exceed soft limit" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		l10n: the subject of a commit has length between 50 and 62

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"
		level=warning msg="commit <OID>: subject is too long (58 > 50)"
		EOF
		git-po-helper check-commits HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "no empty line between subject and body" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		l10n: test: no blank line between subject and body
		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"
		level=error msg="commit <OID>: no blank line between subject and body of commit message"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "no l10n prefix in subject" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		test: no l10n prefix in subject

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: do not have prefix \"l10n:\" in subject"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "non-ascii characters in subject" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		l10n: update translation for zh_CN (简体中文)

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: subject has non-ascii character \"简\""

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "subject end with period" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		l10n: subject should not end with period.

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: subject should not end with period"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "empty commit log" '
	(
		cd workdir &&
		test_tick &&
		git commit --allow-empty -m "remove this line" &&
		git cat-file commit HEAD >.git/commit-meta &&
		sed -e "/^remove this line/ d" <.git/commit-meta \
			>.git/commit-hacked-meta &&

		cid=$(git hash-object -w -t commit .git/commit-hacked-meta) &&
		git update-ref refs/heads/master $cid &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: do not have any commit message"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "oneline commit message" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		l10n: one line commit message (test)
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: cannot find \"Signed-off-by:\" signature"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "no s-o-b signature" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		l10n: test: no s-o-b signature

		This is body of commit log.
		more commit log message...
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: cannot find \"Signed-off-by:\" signature"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "too long message in commit log body" '
	(
		cd workdir &&
		cat >.git/commit-message <<-\EOF &&
		l10n: test: too long commit log message body

		Start body of commit log. This is is a very long commit log message, which exceed 72
		characters.

		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: commit log message is too long (84 > 72)"
		level=error msg="commit <OID>: cannot find \"Signed-off-by:\" signature"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "merge commit" '
	(
		cd workdir &&
		git checkout -b topic/1 &&
		cat >.git/commit-message <<-\EOF &&
		l10n: topic/1

		New commit for topic/1.

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		git checkout master &&
		git merge --no-ff topic/1 &&

		cat >expect <<-EOF &&
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"
		level=warning msg="commit <OID>: author (A U Thor <author@example.com>) and committer (C O Mitter <committer@example.com>) are different"
		EOF
		git-po-helper check-commits -q HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "merge commit subject not start with Merge" '
	(
		cd workdir &&
		git checkout -b topic/2 &&
		cat >.git/commit-message <<-\EOF &&
		l10n: topic/2

		New commit for topic/2.

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&

		git checkout master &&
		git merge --no-ff -m "l10n: a merge commit" topic/2 &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: merge commit does not have prefix \"Merge\" in subject"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "utf-8 characters in commit log" '
	(
		cd workdir &&

		cat >.git/commit-message <<-\EOF &&
		l10n: test: utf-8 commit message

		使用 utf-8 编码的提交说明。

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git commit --allow-empty -F .git/commit-message &&
		git cat-file commit HEAD >.git/commit-meta &&

		cat >expect <<-EOF &&
		EOF
		git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "utf-8 characters in commit log with wrong encoding" '
	(
		cd workdir &&

		cat >.git/commit-message <<-\EOF &&
		l10n: test: utf-8 commit message

		使用 utf-8 编码的提交说明。

		Signed-off-by: Author <author@example.com>
		EOF
		test_tick &&
		git -c i18n.commitencoding=iso-8859-6 commit --allow-empty -F .git/commit-message &&
		git cat-file commit HEAD >.git/commit-meta &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: bad iso-8859-6 characters in: \"使用 utf-8 编码的提交说明。\""
		level=error msg="    illegal byte sequence"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "gbk characters in commit log with proper encoding" '
	(
		cd workdir &&

		cat <<-\EOF |
		l10n: test: gbk commit message

		使用 gbk 编码的提交说明。

		Signed-off-by: Author <author@example.com>
		EOF
		iconv -f UTF-8 -t GBK >.git/commit-message 
		test_tick &&
		git -c i18n.commitencoding=GBK commit --allow-empty -F .git/commit-message &&
		git cat-file commit HEAD >.git/commit-meta &&

		cat >expect <<-EOF &&
		EOF
		git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "gbk characters in commit log with wrong encoding" '
	(
		cd workdir &&

		cat <<-\EOF |
		l10n: test: gbk commit message

		使用 gbk 编码的提交说明。

		Signed-off-by: Author <author@example.com>
		EOF
		iconv -f UTF-8 -t GBK >.git/commit-message 
		test_tick &&
		git -c i18n.commitencoding=iso-8859-6 commit --allow-empty -F .git/commit-message &&
		git cat-file commit HEAD >.git/commit-meta &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: bad iso-8859-6 characters in: \"ʹ\xd3\xc3 gbk \xb1\xe0\xc2\xeb\xb5\xc4\xccύ˵\xc3\xf7\xa1\xa3\""
		level=error msg="    illegal byte sequence"

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_expect_success "bad utf-8 characters in commit log" '
	(
		cd workdir &&

		git cat-file commit HEAD >.git/commit-meta &&
		sed -e "/^encoding /d" <.git/commit-meta \
			>.git/commit-hacked-meta &&

		cid=$(git hash-object -w -t commit .git/commit-hacked-meta) &&
		git update-ref refs/heads/master $cid &&

		cat >expect <<-EOF &&
		level=error msg="commit <OID>: bad UTF-8 characters in: \"ʹ\xd3\xc3 gbk \xb1\xe0\xc2\xeb\xb5\xc4\xccύ˵\xc3\xf7\xa1\xa3\""

		ERROR: fail to execute "git-po-helper check-commits"
		EOF
		test_must_fail git-po-helper check-commits -qq HEAD~..HEAD >out 2>&1 &&
		make_user_friendly_and_stable_output <out >actual &&
		test_cmp expect actual
	)
'

test_done
