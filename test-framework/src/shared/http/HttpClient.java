package shared.http;

import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValueFactory;
import okhttp3.OkHttpClient;
import retrofit2.Call;
import retrofit2.Response;
import retrofit2.Retrofit;
import retrofit2.converter.jackson.JacksonConverterFactory;
import retrofit2.converter.scalars.ScalarsConverterFactory;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

public class HttpClient {

    private static final String BASE_URL = "http://localhost:8080/";

    private final IValueFactory values;

    public HttpClient(final IValueFactory values) {
        this.values = values;
    }

    public IMap sendGet(IString url) {
    	Retrofit retrofit = buildRetrofitClient();

        HttpService service = retrofit.create(HttpService.class);

        Call<String> stringCall = service.sendGet(url.getValue());
        Response<String> response = null;

        try {
            response = stringCall.execute();
        } catch (IOException e) {
            e.printStackTrace();
        }

        return getResponseMap(response);
    }

    public IMap sendPost(IString url, IString body) {
    	Retrofit retrofit = buildRetrofitClient();

        HttpService service = retrofit.create(HttpService.class);

        Call<String> stringCall = service.sendPost(url.getValue(), body.getValue());
        Response<String> response = null;

        try {
            response = stringCall.execute();
        } catch (IOException e) {
            e.printStackTrace();
        }

        return getResponseMap(response);
    }

    private IMap getResponseMap(Response<String> response) {
        IMapWriter mapWriter = values.mapWriter();
        mapWriter.put(values.string("body"), values.string(response.body()));

        try {
            if (response.errorBody() != null) {
                mapWriter.put(values.string("errorBody"), values.string(response.errorBody().string()));
            } else {
                mapWriter.put(values.string("errorBody"), values.string(""));
            }
        } catch (IOException e) {
            mapWriter.put(values.string("errorBody"), values.string(""));
            e.printStackTrace();
        }

        mapWriter.put(values.string("message"), values.string(response.message()));
        mapWriter.put(values.string("code"), values.string(String.valueOf(response.code())));
        mapWriter.put(values.string("isSuccessful"), values.string(String.valueOf(response.isSuccessful())));

        return mapWriter.done();
    }
    
    private Retrofit buildRetrofitClient() {
		OkHttpClient okHttpClient = buildHttpClient();
    	
    	Retrofit retrofit = new Retrofit
                .Builder()
                .baseUrl(BASE_URL)
                .addConverterFactory(ScalarsConverterFactory.create())
                .addConverterFactory(JacksonConverterFactory.create())
                .client(okHttpClient)
                .build();
		return retrofit;
	}
    
    private OkHttpClient buildHttpClient() {
		return new OkHttpClient.Builder()
    	        .readTimeout(60, TimeUnit.SECONDS)
    	        .connectTimeout(60, TimeUnit.SECONDS)
    	        .build();
	}
}
