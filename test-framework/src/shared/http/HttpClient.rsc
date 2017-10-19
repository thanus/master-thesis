module shared::http::HttpClient

@javaClass{shared.http.HttpClient}
public java map[str, str] sendGet(str url);

@javaClass{shared.http.HttpClient}
public java map[str, str] sendPost(str url, str body);