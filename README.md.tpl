### Hi there 👋

#### 🌱 My latest projects
{{range recentRepos 10}}
{{- if .Description}}
- [{{.Name}}]({{.URL}}) - {{.Description}}
{{- end}}
{{- end}}

#### 🔭 Latest releases I've contributed to
{{range recentReleases 10}}
{{- if len .Description}}
- [{{.Name}}]({{.URL}}) ([{{.LastRelease.TagName}}]({{.LastRelease.URL}}), {{humanize .LastRelease.PublishedAt}}) - {{.Description}}
{{- end}}
{{- end}}

<details>
<!--
  <h4>📓 Gists I wrote</h4>
  <ul>
  {{range gists 7}}
  {{- if .Description -}}
  <li><a href="{{.URL}}">{{.Description}}</a> ({{humanize .CreatedAt}})</li>
  {{ end }}
  {{- end}}
  </ul>
-->

  <h4>⭐ Recent Stars</h4>
  <ul>
  {{range recentStars 10}}
  <li><a href="{{.Repo.URL}}">{{.Repo.Name}}</a> - {{.Repo.Description}} ({{humanize .StarredAt}})</li>
  {{- end}}
  </ul>

  {{- $mySponsors := sponsors 5}}
  {{- if $mySponsors }}
  <h4>❤️ These awesome people sponsor me (thank you!)</h4>
  <ul>
  {{range $mySponsors}}
  <li><a href="{{.URL}}">{{.Login}}</a> ({{humanize .CreatedAt}})</li>
  {{- end}}
  </ul>
  {{- end}}

  {{ $myfollowers := followers 5}}
  {{- if $myfollowers}}
  <h4>👯 Check out some of my recent followers</h4>
  <ul>
  {{range followers 5}}
  <li><a href="{{.URL}}">{{.Login}}</a></li>
  {{- end}}
  </ul>
  {{- end}}

  <h4>💬 Feedback</h4>

  <p>
    If you use one of my projects, I'd love to hear from you!
    Don't be shy and let me know what you liked and what needs being improved.
    Got an issue? Open a ticket, I don't bite and will try my best to help!
  </p>

  <h4>📫 How to reach me</h4>
  <ul>
    <li>Twitter: <a href="https://twitter.com/mr_ehbr">https://twitter.com/mr_ehbr</a></li>
  </ul>

  <hr />

  <img src="https://github-readme-stats.vercel.app/api?username=MrEhbr&count_private=true&show_icons=true&theme=dracula"/>
</details>