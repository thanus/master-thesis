package shared.http;

import retrofit2.Call;
import retrofit2.http.*;
import retrofit2.http.Body;

public interface HttpService {

    @Headers({
            "Content-Type: application/json"
    })
    @GET
    Call<String> sendGet(@Url String url);

    @Headers({
            "Content-Type: application/json"
    })
    @POST
    Call<String> sendPost(@Url String url, @Body String body);

}
